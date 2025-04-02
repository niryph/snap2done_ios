import '../models/water_intake_models.dart';

class UnitConverter {
  static const double _mlPerFlOz = 29.5735; // 1 fl oz = 29.5735 ml

  // Convert milliliters to fluid ounces
  static double mlToFlOz(double ml) {
    return ml / _mlPerFlOz;
  }

  // Convert fluid ounces to milliliters
  static double flOzToMl(double flOz) {
    return flOz * _mlPerFlOz;
  }

  // Format amount with appropriate unit
  static String formatAmount(double amount, UnitType unitType) {
    return '${amount.round()} ${unitType == UnitType.fluidOunce ? 'fl oz' : 'ml'}';
  }

  // Get default goal based on unit type
  static double getDefaultGoal(UnitType unitType) {
    return unitType == UnitType.fluidOunce ? 91.0 : 2700.0; // 91 fl oz or 2700 ml
  }
} 