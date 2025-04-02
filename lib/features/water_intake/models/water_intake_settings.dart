class WaterIntakeSettings {
  final double dailyGoal;
  final UnitType unitType;
  final List<Map<String, dynamic>> quickAddOptions;

  WaterIntakeSettings({
    required this.dailyGoal,
    required this.unitType,
    required this.quickAddOptions,
  });

  factory WaterIntakeSettings.fromJson(Map<String, dynamic> json) {
    return WaterIntakeSettings(
      dailyGoal: json['dailyGoal'] ?? 2000.0,
      unitType: UnitType.values[json['unitType'] ?? 0],
      quickAddOptions: List<Map<String, dynamic>>.from(json['quickAddOptions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dailyGoal': dailyGoal,
      'unitType': unitType.index,
      'quickAddOptions': quickAddOptions,
    };
  }
} 