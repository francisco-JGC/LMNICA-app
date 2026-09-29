import 'package:equatable/equatable.dart';

class PrinterDevice extends Equatable {
  const PrinterDevice({
    required this.name,
    required this.address,
    this.isSmartPos = false,
  });

  final String name;
  final String address;
  // Cuando true, usa columnas size1 (32 chars) en vez de size2 (16 × width×2).
  // Actívalo en dispositivos SmartPOS con impresora integrada que imprimen
  // solo el 50% del ancho al usar el comando de doble ancho ESC/POS.
  final bool isSmartPos;

  PrinterDevice copyWith({bool? isSmartPos}) => PrinterDevice(
        name: name,
        address: address,
        isSmartPos: isSmartPos ?? this.isSmartPos,
      );

  @override
  List<Object?> get props => [name, address, isSmartPos];
}
