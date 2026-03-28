import 'metodo_pago.dart';

class Venta {
  final int id;
  final DateTime fecha;
  final double total;
  final MetodoPago metodoPago;

  Venta({
    required this.id,
    required this.fecha,
    required this.total,
    required this.metodoPago,
  });

  // Transforma el JSON que manda Spring Boot a un objeto de Dart
  factory Venta.fromJson(Map<String, dynamic> json) {
    // Buscamos a qué método de pago corresponde el texto (ej: "EFECTIVO")
    MetodoPago metodoParseado = MetodoPago.values.firstWhere(
      (m) => m.name.toUpperCase() == json['metodoPago'].toString().toUpperCase(),
      orElse: () => MetodoPago.efectivo, // Por defecto si hay error
    );

    return Venta(
      id: json['id'],
      fecha: DateTime.parse(json['fecha']),
      total: (json['total'] as num).toDouble(),
      metodoPago: metodoParseado,
    );
  }
}