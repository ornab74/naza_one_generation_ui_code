// Deterministic software-chaos observatory for AION transcript diversity.
// These simulations contribute exactly zero credited cryptographic entropy.
import 'dart:math' as math;
import 'dart:typed_data';

import 'aion_virtual_msl.dart';
import 'metameric_surface_lattice.dart';

final class AionChaosBundle {
  const AionChaosBundle({
    required this.frames,
    required this.divergenceScore,
    required this.steps,
  });

  final List<AionChaosFrame> frames;
  final double divergenceScore;
  final int steps;
  int get entropyCreditBits => 0;
}

/// Produces independent-looking but fully deterministic dynamical projections.
/// The seed should be public/transcript material; secret keys must not be fed
/// into visualization or telemetry surfaces.
final class AionChaosObservatory {
  const AionChaosObservatory({
    this.gridSize = 16,
    this.logisticNodes = 32,
    this.automatonCells = 128,
  });

  final int gridSize;
  final int logisticNodes;
  final int automatonCells;

  AionChaosBundle evolve({
    required Uint8List seed,
    int steps = 96,
    int frameStride = 12,
  }) {
    if (seed.length < 16 ||
        seed.length > 128 ||
        gridSize < 8 ||
        gridSize > 64 ||
        logisticNodes < 8 ||
        logisticNodes > 256 ||
        automatonCells < 32 ||
        automatonCells > 1024 ||
        steps < 8 ||
        steps > 4096 ||
        frameStride < 1 ||
        frameStride > steps) {
      throw const MslProtocolException(
        'aion_observatory_invalid',
        'The chaos observatory configuration is outside its bounded domain.',
      );
    }

    final random = _SeedStream(seed);
    var lx = random.signed(.25);
    var ly = random.signed(.25);
    var lz = 20 + random.unit() * 5;
    final logistic = List<double>.generate(
      logisticNodes,
      (_) => .1 + random.unit() * .8,
    );
    final cells = List<bool>.generate(
      automatonCells,
      (_) => random.nextUint32().isOdd,
    );
    final count = gridSize * gridSize;
    var u = List<double>.filled(count, 1);
    var v = List<double>.filled(count, 0);
    final center = gridSize ~/ 2;
    for (var y = center - 2; y <= center + 2; y++) {
      for (var x = center - 2; x <= center + 2; x++) {
        final index = y * gridSize + x;
        u[index] = .5 + random.signed(.04);
        v[index] = .25 + random.signed(.04);
      }
    }

    final frames = <AionChaosFrame>[];
    var divergenceTotal = 0.0;
    var divergenceCount = 0;
    for (var step = 0; step < steps; step++) {
      // Lorenz-63, RK-like small Euler step within a bounded integration range.
      const dt = .005;
      const sigma = 10.0;
      const rho = 28.0;
      const beta = 8.0 / 3.0;
      final dx = sigma * (ly - lx);
      final dy = lx * (rho - lz) - ly;
      final dz = lx * ly - beta * lz;
      lx += dt * dx;
      ly += dt * dy;
      lz += dt * dz;

      final previous = List<double>.from(logistic);
      for (var i = 0; i < logistic.length; i++) {
        final left = previous[(i - 1 + previous.length) % previous.length];
        final right = previous[(i + 1) % previous.length];
        final local = 3.88 * previous[i] * (1 - previous[i]);
        logistic[i] = (local * .94 + (left + right) * .03).clamp(0, 1);
      }

      final nextU = List<double>.filled(count, 0);
      final nextV = List<double>.filled(count, 0);
      for (var y = 0; y < gridSize; y++) {
        for (var x = 0; x < gridSize; x++) {
          final i = y * gridSize + x;
          final lapU = _laplace(u, x, y);
          final lapV = _laplace(v, x, y);
          final uvv = u[i] * v[i] * v[i];
          nextU[i] = (u[i] + .16 * lapU - uvv + .035 * (1 - u[i])).clamp(0, 1);
          nextV[i] = (v[i] + .08 * lapV + uvv - (.035 + .062) * v[i]).clamp(
            0,
            1,
          );
        }
      }
      u = nextU;
      v = nextV;

      final oldCells = List<bool>.from(cells);
      for (var i = 0; i < cells.length; i++) {
        // Elementary cellular automaton rule 30.
        final left = oldCells[(i - 1 + cells.length) % cells.length];
        final middle = oldCells[i];
        final right = oldCells[(i + 1) % cells.length];
        cells[i] = left ^ (middle || right);
      }

      if (step % frameStride == 0 || step == steps - 1) {
        final coordinates = <double>[
          _unit(lx / 24),
          _unit(ly / 30),
          _unit((lz - 25) / 25),
          ...logistic.map((value) => value * 2 - 1),
          ...v.map((value) => value * 2 - 1),
          ...cells.map((value) => value ? 1.0 : -1.0),
        ];
        if (coordinates.any((value) => !value.isFinite)) {
          throw const MslProtocolException(
            'aion_observatory_fault',
            'A software-chaos model became numerically unstable.',
          );
        }
        final mean = coordinates.reduce((a, b) => a + b) / coordinates.length;
        divergenceTotal +=
            coordinates
                .map((value) => math.pow(value - mean, 2).toDouble())
                .reduce((a, b) => a + b) /
            coordinates.length;
        divergenceCount++;
        frames.add(AionChaosFrame(List<double>.unmodifiable(coordinates)));
      }
    }
    return AionChaosBundle(
      frames: List<AionChaosFrame>.unmodifiable(frames),
      divergenceScore: divergenceCount == 0
          ? 0
          : (divergenceTotal / divergenceCount).clamp(0, 1),
      steps: steps,
    );
  }

  double _laplace(List<double> values, int x, int y) {
    int at(int dx, int dy) {
      final px = (x + dx + gridSize) % gridSize;
      final py = (y + dy + gridSize) % gridSize;
      return py * gridSize + px;
    }

    return values[at(-1, 0)] +
        values[at(1, 0)] +
        values[at(0, -1)] +
        values[at(0, 1)] -
        4 * values[at(0, 0)];
  }

  static double _unit(double value) =>
      (2 / (1 + math.exp(-2 * value)) - 1).clamp(-1, 1);
}

final class _SeedStream {
  _SeedStream(Uint8List seed) : _seed = seed;
  final Uint8List _seed;
  var _offset = 0;

  int nextUint32() {
    var value = 0x9e3779b9 ^ _offset;
    for (var i = 0; i < 8; i++) {
      value ^= _seed[(_offset + i) % _seed.length] << ((i % 4) * 8);
      value = ((value << 13) | (value >>> 19)) & 0xffffffff;
      value = (value * 0x85ebca6b) & 0xffffffff;
    }
    _offset += 7;
    return value;
  }

  double unit() => nextUint32() / 0xffffffff;
  double signed(double magnitude) => (unit() * 2 - 1) * magnitude;
}
