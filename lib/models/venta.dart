import 'metodo_pago.dart';
import 'detalle_venta.dart'; 

class PagoVenta {
  final MetodoPago metodoPago;
  final double monto;

  PagoVenta({required this.metodoPago, required this.monto});

  factory PagoVenta.fromJson(Map<String, dynamic> json) {
    MetodoPago metodoParseado = MetodoPago.values.firstWhere(
      (m) => m.name.toUpperCase() == (json['metodoPago'] ?? '').toString().toUpperCase(),
      orElse: () => MetodoPago.efectivo,
    );
    return PagoVenta(
      metodoPago: metodoParseado,
      monto: (json['monto'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Venta {
  final int id;
  final DateTime? fecha;
  final double total;
  final String estado; // 🔥 NUEVO: Para saber si está CANCELADA o COMPLETADA
  final List<PagoVenta>? pagos; 
  final List<DetalleVenta> detalles; 

  Venta({
    required this.id,
    this.fecha,
    required this.total,
    required this.estado,
    this.pagos,
    required this.detalles,
  });

  factory Venta.fromJson(Map<String, dynamic> json) {
    DateTime? parsedFecha;
    if (json['fecha'] != null) {
      parsedFecha = DateTime.tryParse(json['fecha']);
    }

    List<PagoVenta> parsedPagos = [];
    if (json['pagos'] != null) {
      parsedPagos = (json['pagos'] as List).map((p) => PagoVenta.fromJson(p)).toList();
    } else if (json['metodoPago'] != null) {
      MetodoPago metodoAntiguo = MetodoPago.values.firstWhere(
        (m) => m.name.toUpperCase() == json['metodoPago'].toString().toUpperCase(),
        orElse: () => MetodoPago.efectivo,
      );
      parsedPagos.add(PagoVenta(metodoPago: metodoAntiguo, monto: (json['total'] as num).toDouble()));
    }

    List<DetalleVenta> parsedDetalles = [];
    if (json['detalles'] != null) {
      parsedDetalles = (json['detalles'] as List).map((d) => DetalleVenta.fromJson(d)).toList();
    }

    return Venta(
      id: json['id'] ?? 0,
      fecha: parsedFecha ?? DateTime.now(),
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      estado: json['estado'] ?? 'COMPLETADA', // 🔥 Leemos el estado
      pagos: parsedPagos,
      detalles: parsedDetalles,
    );
  }
}