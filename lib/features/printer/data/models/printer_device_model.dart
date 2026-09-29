import '../../domain/entities/printer_device.dart';

class PrinterDeviceModel extends PrinterDevice {
  const PrinterDeviceModel({
    required super.name,
    required super.address,
    super.isSmartPos = false,
  });

  factory PrinterDeviceModel.fromJson(Map<String, dynamic> json) {
    return PrinterDeviceModel(
      name: json['name'] as String,
      address: json['address'] as String,
      isSmartPos: json['isSmartPos'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'isSmartPos': isSmartPos,
      };
}
