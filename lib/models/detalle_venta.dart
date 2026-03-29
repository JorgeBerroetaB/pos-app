import 'producto.dart';

class DetalleVenta {
  final Producto producto;
  int cantidad;
  
  // Campo opcional para guardar un precio editado manualmente o de balanza
  double? precioAplicado; 

  // Helper para saber qué precio usar (el editado o el original)
  double get precioParaVenta => precioAplicado ?? producto.precioVenta;

  // El subtotal ahora usa el precio real de venta
  double get subtotal => precioParaVenta * cantidad;

  DetalleVenta({
    required this.producto,
    this.cantidad = 1, // Por defecto, cuando escaneas algo, es 1 unidad
    this.precioAplicado, // Opcional
  });

  // ========================================================
  // 🔥 ¡NUEVO! Para leer los datos del backend (Historial de Ventas)
  // ========================================================
  factory DetalleVenta.fromJson(Map<String, dynamic> json) {
    // Calculamos el precio al que se vendió en ese momento exacto
    double? precioCalculado;
    if (json['subtotal'] != null && json['cantidad'] != null && json['cantidad'] > 0) {
      precioCalculado = (json['subtotal'] as num).toDouble() / (json['cantidad'] as num).toInt();
    }

    return DetalleVenta(
      producto: Producto.fromJson(json['producto']),
      cantidad: json['cantidad'] ?? 1,
      precioAplicado: precioCalculado,
    );
  }

  // ========================================================
  // Para enviar los datos al backend al momento de cobrar
  // ========================================================
  Map<String, dynamic> toJson() {
    return {
      "producto": {
        "sku": producto.sku // Solo necesitamos mandarle el SKU al backend
      },
      "cantidad": cantidad,
      "precioUnitarioCobrado": precioParaVenta, // Opcional, por si lo usas
      // ¡NUEVO! Le avisamos al backend cuánto es el subtotal exacto de este producto
      "subtotal": subtotal 
    };
  }
}