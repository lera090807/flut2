import 'dart:convert';
import 'dart:io';

import 'package:cosmetics/repositories/seed_data.dart';

void main() {
  File('api/seed.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'products': seedProducts.map((e) => e.toJson()).toList(),
      'brands': seedBrands.map((e) => e.toJson()).toList(),
      'categories': seedCategories.map((e) => e.toJson()).toList(),
      'suppliers': seedSuppliers.map((e) => e.toJson()).toList(),
      'customers': seedCustomers.map((e) => e.toJson()).toList(),
    }),
  );
}
