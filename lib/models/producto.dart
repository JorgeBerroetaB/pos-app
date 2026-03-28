class Producto {
  final String sku;
  final String nombre;
  final double precioVenta;
  final double precioCosto;
  final int stock;

  Producto({
    required this.sku,
    required this.nombre,
    required this.precioVenta,
    required this.precioCosto,
    required this.stock,
  });

  // Esta función es la traductora: Convierte el JSON que manda Spring Boot a un Objeto de Dart
  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      sku: json['sku'],
      nombre: json['nombre'],
      // Usamos .toDouble() porque a veces los enteros en JSON confunden a Dart
      precioVenta: json['precioVenta'].toDouble(),
      precioCosto: json['precioCosto'].toDouble(),
      stock: json['stock'],
    );
  }

  // Esta función hace lo contrario: Convierte el Objeto de Dart a JSON para mandarlo a Spring Boot
  Map<String, dynamic> toJson() {
    return {
      'sku': sku,
      'nombre': nombre,
      'precioVenta': precioVenta,
      'precioCosto': precioCosto,
      'stock': stock,
    };
  }
}