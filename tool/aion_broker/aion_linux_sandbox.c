#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <linux/audit.h>
#include <linux/filter.h>
#include <linux/landlock.h>
#include <linux/seccomp.h>
#include <signal.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <sys/ptrace.h>
#include <sys/resource.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <unistd.h>

extern char **environ;

#if defined(__x86_64__)
#define AION_AUDIT_ARCH AUDIT_ARCH_X86_64
#elif defined(__aarch64__)
#define AION_AUDIT_ARCH AUDIT_ARCH_AARCH64
#else
#error "AION sandbox supports only x86_64 and aarch64 Linux"
#endif

#define DENY_SYSCALL(number)                                                   \
  BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, (number), 0, 1),                       \
      BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ERRNO | (EPERM & 0xffff))

static int install_network_filter(void) {
  struct sock_filter filter[] = {
      BPF_STMT(BPF_LD | BPF_W | BPF_ABS,
               (uint32_t)offsetof(struct seccomp_data, arch)),
      BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, AION_AUDIT_ARCH, 1, 0),
      BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_KILL_PROCESS),
      BPF_STMT(BPF_LD | BPF_W | BPF_ABS,
               (uint32_t)offsetof(struct seccomp_data, nr)),
      DENY_SYSCALL(__NR_socket),
      DENY_SYSCALL(__NR_socketpair),
      DENY_SYSCALL(__NR_connect),
      DENY_SYSCALL(__NR_bind),
      DENY_SYSCALL(__NR_listen),
      DENY_SYSCALL(__NR_accept),
      DENY_SYSCALL(__NR_accept4),
      DENY_SYSCALL(__NR_sendto),
      DENY_SYSCALL(__NR_recvfrom),
      DENY_SYSCALL(__NR_ptrace),
      DENY_SYSCALL(__NR_process_vm_readv),
      DENY_SYSCALL(__NR_process_vm_writev),
      DENY_SYSCALL(__NR_mount),
      DENY_SYSCALL(__NR_umount2),
      DENY_SYSCALL(__NR_pivot_root),
      DENY_SYSCALL(__NR_chroot),
      DENY_SYSCALL(__NR_bpf),
      DENY_SYSCALL(__NR_userfaultfd),
      DENY_SYSCALL(__NR_keyctl),
      DENY_SYSCALL(__NR_add_key),
      DENY_SYSCALL(__NR_request_key),
      DENY_SYSCALL(__NR_init_module),
      DENY_SYSCALL(__NR_finit_module),
      DENY_SYSCALL(__NR_delete_module),
      DENY_SYSCALL(__NR_kexec_load),
      DENY_SYSCALL(__NR_reboot),
      BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ALLOW),
  };
  struct sock_fprog program = {
      .len = (unsigned short)(sizeof(filter) / sizeof(filter[0])),
      .filter = filter,
  };
  return prctl(PR_SET_SECCOMP, SECCOMP_MODE_FILTER, &program);
}

static uint64_t handled_access_fs(int abi) {
  uint64_t access = LANDLOCK_ACCESS_FS_EXECUTE | LANDLOCK_ACCESS_FS_WRITE_FILE |
                    LANDLOCK_ACCESS_FS_READ_FILE | LANDLOCK_ACCESS_FS_READ_DIR |
                    LANDLOCK_ACCESS_FS_REMOVE_DIR |
                    LANDLOCK_ACCESS_FS_REMOVE_FILE |
                    LANDLOCK_ACCESS_FS_MAKE_CHAR |
                    LANDLOCK_ACCESS_FS_MAKE_DIR |
                    LANDLOCK_ACCESS_FS_MAKE_REG |
                    LANDLOCK_ACCESS_FS_MAKE_SOCK |
                    LANDLOCK_ACCESS_FS_MAKE_FIFO |
                    LANDLOCK_ACCESS_FS_MAKE_BLOCK |
                    LANDLOCK_ACCESS_FS_MAKE_SYM;
#ifdef LANDLOCK_ACCESS_FS_REFER
  if (abi >= 2) access |= LANDLOCK_ACCESS_FS_REFER;
#endif
#ifdef LANDLOCK_ACCESS_FS_TRUNCATE
  if (abi >= 3) access |= LANDLOCK_ACCESS_FS_TRUNCATE;
#endif
  return access;
}

static int add_read_path(int ruleset_fd, const char *path) {
  int path_fd = open(path, O_PATH | O_CLOEXEC);
  if (path_fd < 0) return -1;
  struct landlock_path_beneath_attr rule = {
      .allowed_access = LANDLOCK_ACCESS_FS_EXECUTE |
                        LANDLOCK_ACCESS_FS_READ_FILE |
                        LANDLOCK_ACCESS_FS_READ_DIR,
      .parent_fd = path_fd,
  };
  int result = (int)syscall(__NR_landlock_add_rule, ruleset_fd,
                            LANDLOCK_RULE_PATH_BENEATH, &rule, 0);
  close(path_fd);
  return result;
}

static int install_landlock(char **paths, int path_count) {
  int abi = (int)syscall(__NR_landlock_create_ruleset, NULL, 0,
                         LANDLOCK_CREATE_RULESET_VERSION);
  if (abi < 3) {
    errno = ENOTSUP;
    return -1;
  }
  struct landlock_ruleset_attr ruleset = {
      .handled_access_fs = handled_access_fs(abi),
  };
  int ruleset_fd = (int)syscall(__NR_landlock_create_ruleset, &ruleset,
                                sizeof(ruleset), 0);
  if (ruleset_fd < 0) return -1;
  for (int index = 0; index < path_count; index++) {
    if (paths[index][0] != '/' || add_read_path(ruleset_fd, paths[index]) < 0) {
      close(ruleset_fd);
      errno = EINVAL;
      return -1;
    }
  }
  int result = (int)syscall(__NR_landlock_restrict_self, ruleset_fd, 0);
  close(ruleset_fd);
  return result;
}

static int apply_process_limits(void) {
  struct rlimit core = {.rlim_cur = 0, .rlim_max = 0};
  struct rlimit files = {.rlim_cur = 32, .rlim_max = 32};
  struct rlimit memory = {.rlim_cur = 512 * 1024 * 1024,
                          .rlim_max = 512 * 1024 * 1024};
  struct rlimit cpu = {.rlim_cur = 10, .rlim_max = 10};
  if (setrlimit(RLIMIT_CORE, &core) || setrlimit(RLIMIT_NOFILE, &files) ||
      setrlimit(RLIMIT_AS, &memory) || setrlimit(RLIMIT_CPU, &cpu))
    return -1;
  if (prctl(PR_SET_DUMPABLE, 0) || prctl(PR_SET_PDEATHSIG, SIGKILL) ||
      prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0))
    return -1;
  umask(077);
  return getppid() == 1 ? -1 : 0;
}

static int self_test(void) {
  if (apply_process_limits() || install_landlock(NULL, 0) ||
      install_network_filter())
    return 70;
  int file_fd = open("/etc/passwd", O_RDONLY | O_CLOEXEC);
  if (file_fd >= 0) {
    close(file_fd);
    return 71;
  }
  int network_fd = socket(AF_INET, SOCK_STREAM | SOCK_CLOEXEC, 0);
  if (network_fd >= 0) {
    close(network_fd);
    return 72;
  }
  if (errno != EPERM && errno != EACCES) return 73;
  errno = 0;
  if (ptrace(PTRACE_TRACEME, 0, NULL, NULL) == 0 || errno != EPERM) return 74;
  return 0;
}

int main(int argc, char **argv) {
  if (argc == 2 && strcmp(argv[1], "--self-test") == 0) return self_test();
  if (argc < 4 || strcmp(argv[1], "--") != 0) {
    fputs("usage: aion_linux_sandbox -- /absolute/broker [read-path ...]\n",
          stderr);
    return 64;
  }
  const char *broker_path = argv[2];
  if (broker_path[0] != '/') return 65;
  int broker_fd = open(broker_path, O_PATH | O_CLOEXEC | O_NOFOLLOW);
  struct stat metadata;
  if (broker_fd < 0 || fstat(broker_fd, &metadata) ||
      !S_ISREG(metadata.st_mode) || metadata.st_uid != 0 ||
      (metadata.st_mode & (S_IWUSR | S_IWGRP | S_IWOTH))) {
    if (broker_fd >= 0) close(broker_fd);
    return 66;
  }
  if (apply_process_limits()) return 67;
  if (setsid() < 0) return 68;
  if (install_landlock(&argv[2], argc - 2)) return 68;
  if (install_network_filter()) return 69;

  if (broker_fd != 3) {
    if (dup3(broker_fd, 3, O_CLOEXEC) < 0) return 70;
    close(broker_fd);
    broker_fd = 3;
  }
#ifdef __NR_close_range
  if (syscall(__NR_close_range, 4U, ~0U, 0) < 0 && errno != ENOSYS) return 71;
#else
  for (int descriptor = 4; descriptor < 32; descriptor++) close(descriptor);
#endif

  char *broker_argv[] = {(char *)broker_path, NULL};
  char *clean_environment[] = {"LANG=C", "TZ=UTC", NULL};
  environ = clean_environment;
  fexecve(broker_fd, broker_argv, clean_environment);
  return 75;
}
