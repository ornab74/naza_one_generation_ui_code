import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:naza_one/naza_rev_recall/app/app_scope.dart';
import 'package:naza_one/naza_rev_recall/app/app_theme.dart';
import 'package:naza_one/naza_rev_recall/data/car_catalog.dart';
import 'package:naza_one/naza_rev_recall/models/car_profile.dart';
import 'package:naza_one/naza_rev_recall/widgets/car_wheel.dart';
import 'package:naza_one/naza_rev_recall/widgets/neon_widgets.dart';

class GarageScreen extends StatelessWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 4 : 3;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CAR GARAGE',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Choose 4–8 distinct engine sounds for the memory wheel.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.purple.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.purple),
                              ),
                              child: Text(
                                '${app.activeCarIds.length}/8 ACTIVE',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: CarWheel(
                            cars: app.activeCars,
                            centerLabel: 'GRID',
                            size: math.min(260.0, constraints.maxWidth - 70),
                            enabled: false,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const SectionTitle(title: 'Specific car profiles'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              sliver: SliverLayoutBuilder(
                builder: (context, sliverConstraints) {
                  final itemWidth =
                      (math.min(sliverConstraints.crossAxisExtent, 900.0) -
                          ((columns - 1) * 10)) /
                      columns;
                  return SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: itemWidth / 174,
                    ),
                    itemCount: carCatalog.length,
                    itemBuilder: (context, index) {
                      final car = carCatalog[index];
                      return _CarCard(
                        car: car,
                        selected: app.activeCarIds.contains(car.id),
                        onToggle: () {
                          final changed = app.toggleActiveCar(car.id);
                          if (!changed) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  app.activeCarIds.contains(car.id)
                                      ? 'Keep at least four cars active.'
                                      : 'The wheel can hold eight cars. Remove one first.',
                                ),
                              ),
                            );
                          }
                        },
                        onPreview: () {
                          app.recordCarPreview(car.id);
                          unawaited(
                            AppScope.audioOf(
                              context,
                            ).play(car, volume: app.engineVolume),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CarCard extends StatelessWidget {
  const _CarCard({
    required this.car,
    required this.selected,
    required this.onToggle,
    required this.onPreview,
  });

  final CarProfile car;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return NeonPanel(
      onTap: onToggle,
      padding: const EdgeInsets.all(11),
      borderColor: selected ? car.color : AppColors.border,
      glowColor: selected ? car.color : null,
      child: Column(
        children: [
          Row(
            children: [
              Icon(car.icon, color: car.color, size: 30),
              const Spacer(),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline_rounded,
                color: selected ? AppColors.green : AppColors.muted,
                size: 20,
              ),
            ],
          ),
          const Spacer(),
          Text(
            car.shortName,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            car.engine,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 9),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPreview,
              icon: const Icon(Icons.volume_up_rounded, size: 16),
              label: const Text('REV', style: TextStyle(fontSize: 10)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 7),
                foregroundColor: car.color,
                side: BorderSide(color: car.color.withValues(alpha: 0.55)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
