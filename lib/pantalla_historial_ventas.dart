import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'models/venta.dart';
import 'package:intl/intl.dart'; // Para formatear la fecha y la moneda

class PantallaHistorialVentas extends StatefulWidget {
  const PantallaHistorialVentas({super.key});

  @override
  State<PantallaHistorialVentas> createState() => _PantallaHistorialVentasState();
}

class _PantallaHistorialVentasState extends State<PantallaHistorialVentas> {
  final ApiService apiService = ApiService();
  late Future<List<Venta>> _ventasFuture;

  @override
  void initState() {
    super.initState();
    _cargarVentas();
  }

  void _cargarVentas() {
    setState(() {
      _ventasFuture = apiService.obtenerVentas();
    });
  }

  // --- POPUP PARA VER EL DETALLE EXACTO DE LA VENTA ---
  void _mostrarDetalleVenta(Venta venta) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('🧾 Detalle Venta #${venta.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fecha
                  Text(
                    'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(venta.fecha ?? DateTime.now())}',
                    style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const Divider(thickness: 2),
                  
                  // Productos
                  const Text('🛒 PRODUCTOS:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  ...venta.detalles.map((detalle) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('${detalle.cantidad}x ${detalle.producto.nombre}')),
                        Text('\$${detalle.subtotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )).toList(),
                  
                  const Divider(thickness: 2),
                  
                  // Métodos de Pago
                  const Text('💳 PAGOS:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  // Asumiendo que tu modelo Venta tiene una lista de pagos. Si no, ¡lo ajustamos!
                  if (venta.pagos != null && venta.pagos!.isNotEmpty)
                    ...venta.pagos!.map((pago) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(pago.metodoPago.toString()),
                          Text('\$${pago.monto.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )).toList()
                  else
                    const Text('Pago antiguo (Sin detalle)'),

                  const Divider(thickness: 2),
                  
                  // Total final
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('\$${venta.total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, color: Colors.blue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Ventas 📊', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarVentas, // Botón para recargar la lista
          )
        ],
      ),
      body: FutureBuilder<List<Venta>>(
        future: _ventasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 10),
                  Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 18)),
                ],
              )
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aún no hay ventas registradas. 🛒', style: TextStyle(fontSize: 20, color: Colors.grey)));
          }

          final ventas = snapshot.data!;

          // Invertimos la lista para que las ventas más nuevas salgan arriba
          final ventasOrdenadas = ventas.reversed.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: ventasOrdenadas.length,
            itemBuilder: (context, index) {
              final venta = ventasOrdenadas[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueGrey,
                    child: Icon(Icons.receipt_long, color: Colors.white),
                  ),
                  title: Text(
                    'Venta #${venta.id}', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                  ),
                  subtitle: Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(venta.fecha ?? DateTime.now()),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '\$${venta.total.toStringAsFixed(0)}', 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 18)
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    ],
                  ),
                  onTap: () => _mostrarDetalleVenta(venta), // ¡Abre el popup!
                ),
              );
            },
          );
        },
      ),
    );
  }
}