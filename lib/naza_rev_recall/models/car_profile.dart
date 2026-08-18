import 'package:flutter/material.dart';

@immutable
class CarProfile {
  const CarProfile({
    required this.id,
    required this.name,
    required this.shortName,
    required this.engine,
    required this.description,
    required this.assetPath,
    required this.color,
    required this.icon,
  });

  final String id;
  final String name;
  final String shortName;
  final String engine;
  final String description;
  final String assetPath;
  final Color color;
  final IconData icon;
}
