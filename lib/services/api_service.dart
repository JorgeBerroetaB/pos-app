import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/producto.dart';
import '../models/detalle_venta.dart'; // ¡Agregado para que reconozca el carrito de compras!
import '../models/metodo_pago.dart'; // ¡NUEVO IMPORT PARA EL MÉTODO DE PAGO!
import '../models/venta.dart'; // ¡Nuevo import para leer el historial!

class ApiService {
  static const String baseUrl = 'http://localhost:8080/api/productos';
  static const String ventasUrl = 'http://localhost:8080/api/ventas'; // ¡Nueva URL para la caja!

  // 1. Traer todos los productos
  Future<List<Producto>> obtenerTodos() async {
    final response = await http.get(Uri.parse(baseUrl));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      return jsonResponse.map((item) => Producto.fromJson(item)).toList();
    } else {
      throw Exception('Error al cargar productos');
    }
  }

  // 2. Buscar por SKU exacto
  Future<Producto?> buscarPorSku(String sku) async {
    final response = await http.get(Uri.parse('$baseUrl/$sku'));
    if (response.statusCode == 200) {
      return Producto.fromJson(json.decode(utf8.decode(response.bodyBytes)));
    } else if (response.statusCode == 404) {
      return null; // Retorna nulo si no lo encuentra
    } else {
      throw Exception('Error al buscar el producto');
    }
  }

  // Nueva función: Buscar por término (nombre o fragmento de SKU)
  Future<List<Producto>> buscarProductos(String termino) async {
    // Llamamos a la nueva ruta que creamos en Spring Boot
    final response = await http.get(Uri.parse('$baseUrl/buscar?termino=$termino'));
    
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      return jsonResponse.map((item) => Producto.fromJson(item)).toList();
    } else {
      throw Exception('Error al buscar productos');
    }
  }

  // 3. Eliminar un producto
  Future<void> eliminarProducto(String sku) async {
    final response = await http.delete(Uri.parse('$baseUrl/$sku'));
    if (response.statusCode != 204) {
      throw Exception('Error al eliminar el producto');
    }
  }

  // 4. Crear un producto nuevo
  Future<void> crearProducto(Producto producto) async {
    await http.post(
      Uri.parse(baseUrl),
      headers: {"Content-Type": "application/json"},
      body: json.encode(producto.toJson()),
    );
  }

  // 5. Actualizar un producto existente
  Future<void> actualizarProducto(String sku, Producto producto) async {
    await http.put(
      Uri.parse('$baseUrl/$sku'),
      headers: {"Content-Type": "application/json"},
      body: json.encode(producto.toJson()),
    );
  }

  // --- ¡MODIFICADO MÓDULO DE VENTAS! ---
  // Ahora recibe el carrito y el método de pago seleccionado en el popup
  Future<void> registrarVenta(List<DetalleVenta> carrito, MetodoPago metodoPago) async {
    // 1. Convertimos nuestra lista de objetos a una lista de JSONs (solo los detalles)
    List<Map<String, dynamic>> carritoJson = carrito.map((item) => item.toJson()).toList();

    // 2. Armamos el objeto de venta completo tal cual lo espera el backend (Java)
    final datosVenta = {
      "detalles": carritoJson,
      "metodoPago": metodoPago.name.toUpperCase() // Convierte "efectivo" a "EFECTIVO"
    };

    final response = await http.post(
      Uri.parse(ventasUrl),
      headers: {"Content-Type": "application/json"},
      body: json.encode(datosVenta),
    );

    if (response.statusCode != 201) {
      // Si el backend da error (ej. No hay stock), lanzamos la excepción con el mensaje del servidor
      throw Exception(response.body);
    }
  }

  // --- OBTENER HISTORIAL DE VENTAS ---
  Future<List<Venta>> obtenerVentas() async {
    final response = await http.get(Uri.parse(ventasUrl));
    
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      return jsonResponse.map((item) => Venta.fromJson(item)).toList();
    } else {
      throw Exception('Error al cargar el historial de ventas');
    }
  }
}