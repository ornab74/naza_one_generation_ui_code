import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';

typedef DoorDashProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

final class DoorDashCliProbe {
  final bool platformSupported;
  final bool installed;
  final String detail;
  final String version;
  final bool jsonMentionedInHelp;

  const DoorDashCliProbe({
    required this.platformSupported,
    required this.installed,
    required this.detail,
    this.version = '',
    this.jsonMentionedInHelp = false,
  });
}

final class DoorDashOrderHandoff {
  final String planId;
  final String agentBrief;
  final String payloadJson;
  final DateTime createdAt;

  const DoorDashOrderHandoff({
    required this.planId,
    required this.agentBrief,
    required this.payloadJson,
    required this.createdAt,
  });
}

abstract interface class DoorDashOrderingGateway {
  Future<DoorDashCliProbe> probe();

  DoorDashOrderHandoff createApprovedHandoff(PantryOrderPlan plan);
}

/// Safe bridge boundary for DoorDash's waitlist-gated `dd-cli` beta.
///
/// Public sources currently describe capabilities but do not publish a stable
/// command grammar. This adapter therefore probes only non-purchasing
/// `--version`/`--help` commands and emits an approved, bounded JSON handoff.
/// It never constructs guessed checkout arguments or executes model text.
final class DoorDashCliGateway implements DoorDashOrderingGateway {
  DoorDashCliGateway({
    DoorDashProcessRunner? processRunner,
    String? operatingSystem,
    this.executable = 'dd-cli',
  }) : _processRunner = processRunner ?? _run,
       _operatingSystem = operatingSystem ?? Platform.operatingSystem;

  final DoorDashProcessRunner _processRunner;
  final String _operatingSystem;
  final String executable;

  static Future<ProcessResult> _run(String executable, List<String> arguments) {
    return Process.run(
      executable,
      arguments,
      runInShell: false,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    ).timeout(const Duration(seconds: 8));
  }

  @override
  Future<DoorDashCliProbe> probe() async {
    if (_operatingSystem != 'macos') {
      return const DoorDashCliProbe(
        platformSupported: false,
        installed: false,
        detail:
            'DoorDash announced the limited beta for U.S./Canadian macOS developers. Pantry planning and handoff export still work here.',
      );
    }
    try {
      final version = await _processRunner(executable, const <String>[
        '--version',
      ]);
      final help = await _processRunner(executable, const <String>['--help']);
      final helpText = '${help.stdout}\n${help.stderr}';
      final installed = version.exitCode == 0 || help.exitCode == 0;
      return DoorDashCliProbe(
        platformSupported: true,
        installed: installed,
        detail: installed
            ? 'DoorDash CLI detected. Review and copy the approved agent brief; the app will not guess beta checkout arguments.'
            : 'DoorDash CLI was found but did not return a successful version or help response.',
        version: boundedText('${version.stdout}\n${version.stderr}', 240),
        jsonMentionedInHelp: helpText.toLowerCase().contains('json'),
      );
    } on ProcessException {
      return const DoorDashCliProbe(
        platformSupported: true,
        installed: false,
        detail:
            'dd-cli was not found. Join the DoorDash beta and install its official macOS package before checkout handoff.',
      );
    } on TimeoutException {
      return const DoorDashCliProbe(
        platformSupported: true,
        installed: false,
        detail: 'dd-cli did not answer a non-purchasing capability probe.',
      );
    } catch (error) {
      return DoorDashCliProbe(
        platformSupported: true,
        installed: false,
        detail:
            'DoorDash CLI capability check failed: ${boundedText(error, 240)}',
      );
    }
  }

  @override
  DoorDashOrderHandoff createApprovedHandoff(PantryOrderPlan plan) {
    if (plan.status != PantryOrderStatus.approved) {
      throw StateError('Approve the reviewed plan before creating a handoff.');
    }
    final selected = plan.lines.where((line) => line.selected).toList();
    if (selected.isEmpty) {
      throw StateError('The approved plan has no selected items.');
    }
    if (plan.budgetCap > 0 && plan.estimatedTotal > plan.budgetCap) {
      throw StateError('The approved estimate exceeds its budget cap.');
    }

    final payload = <String, Object?>{
      'format': 'naza-doordash-agent-brief-v1',
      'plan_id': plan.id,
      'approval_recorded_at': plan.approvedAt?.toUtc().toIso8601String(),
      'budget_cap': plan.budgetCap,
      'estimated_total_before_live_pricing': plan.estimatedTotal,
      'requirements': selected
          .map(
            (line) => <String, Object?>{
              'name': line.name,
              'quantity': line.quantity,
              'unit': line.unit,
              'category': line.category.name,
              'maximum_estimate': line.estimatedTotal,
              'verify_with_user_if_ambiguous': line.needsVerification,
            },
          )
          .toList(growable: false),
      'deal_queries': plan.advisory.dealQueries,
      'optional_substitutions': plan.advisory.substitutions,
      'verification_warnings': plan.advisory.warnings,
      'agent_rules': <String>[
        'Search live DoorDash stores and prices; do not treat estimates as live facts.',
        'Do not exceed the budget cap after taxes, fees, tip, and substitutions.',
        'Do not add unlisted products.',
        'Ask the user to resolve unavailable items, ambiguous variants, or a higher total.',
        'Show the final merchant, items, quantities, substitutions, fees, tip, delivery address summary, and total before checkout.',
        'Require a fresh user confirmation immediately before the irreversible checkout action.',
      ],
    };
    final payloadJson = const JsonEncoder.withIndent('  ').convert(payload);
    return DoorDashOrderHandoff(
      planId: plan.id,
      payloadJson: payloadJson,
      createdAt: DateTime.now().toUtc(),
      agentBrief:
          '''
Use the official DoorDash CLI beta to fulfill this approved replenishment plan.

First search and build a proposed cart. Then show the full final cart, merchant, substitutions, taxes, fees, tip, delivery-address summary, and total. Do not check out until I give a fresh confirmation after seeing that final cart.

$payloadJson
''',
    );
  }
}
