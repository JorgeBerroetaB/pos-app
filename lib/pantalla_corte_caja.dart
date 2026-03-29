import 'package:flutter/material.dart';
import 'models/venta.dart';
import 'models/metodo_pago.dart';
import 'services/api_service.dart';

class PantallaCorteCaja extends StatefulWidget {
  const PantallaCorteCaja({super.key});

  @override
  State<PantallaCorteCaja> createState() => _PantallaCorteCajaState();
}

class _PantallaCorteCajaState extends State<PantallaCorteCaja> {
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

  // --- WIDGET DE TARJETAS RECTANGULARES ---
  Widget _construirTarjetaResumen(String titulo, double monto, IconData icono, Color color) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icono, size: 30, color: color),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            Text('\$${monto.toStringAsFixed(0)}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Corte de Caja Diario 📊', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _cargarVentas),
        ],
      ),
      backgroundColor: Colors.grey[200],
      body: FutureBuilder<List<Venta>>(
        future: _ventasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          
          final todasLasVentas = snapshot.data ?? [];
          
          final hoy = DateTime.now();
          final ventasHoy = todasLasVentas.where((v) {
            final fechaVenta = v.fecha ?? DateTime.now();
            return fechaVenta.year == hoy.year && fechaVenta.month == hoy.month && fechaVenta.day == hoy.day;
          }).toList();

          double totalGeneral = 0;
          double totalEfectivo = 0;
          double totalTarjeta = 0;
          double totalTransferencia = 0;
          
          // 🔥 NUEVO: Sumar aparte lo que se canceló
          double totalCancelado = 0;
          int cantidadCanceladas = 0;
          int cantidadCompletadas = 0;

          for (var venta in ventasHoy) {
            // Si la venta está cancelada, la sumamos al pozo de anuladas y la saltamos
            if (venta.estado == 'CANCELADA') {
              totalCancelado += venta.total;
              cantidadCanceladas++;
              continue; 
            }

            // Si llegamos aquí, es porque la venta fue COMPLETADA
            cantidadCompletadas++;
            totalGeneral += venta.total;
            
            if (venta.pagos != null) {
              for (var pago in venta.pagos!) {
                if (pago.metodoPago == MetodoPago.efectivo) totalEfectivo += pago.monto;
                else if (pago.metodoPago == MetodoPago.tarjeta) totalTarjeta += pago.monto;
                else if (pago.metodoPago == MetodoPago.transferencia) totalTransferencia += pago.monto;
              }
            }
          }

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Resumen del Día', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text('${hoy.day}/${hoy.month}/${hoy.year} - $cantidadCompletadas ventas exitosas | $cantidadCanceladas anuladas', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 20),

                Expanded(
                  child: ListView(
                    children: [
                      _construirTarjetaResumen('TOTAL INGRESOS HOY', totalGeneral, Icons.account_balance_wallet, Colors.blue),
                      _construirTarjetaResumen('EFECTIVO EN CAJA', totalEfectivo, Icons.payments, Colors.green),
                      _construirTarjetaResumen('PAGOS CON TARJETA', totalTarjeta, Icons.credit_card, Colors.orange),
                      _construirTarjetaResumen('TRANSFERENCIAS', totalTransferencia, Icons.sync_alt, Colors.purple),
                      
                      const Divider(height: 40, thickness: 2),
                      
                      // 🔥 NUEVA TARJETA: VENTAS CANCELADAS
                      _construirTarjetaResumen('VENTAS ANULADAS (No suman a caja)', totalCancelado, Icons.block, Colors.red),
                      
                      const SizedBox(height: 30),
                    ],
                  ),
                ),

                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Imprimiendo Ticket Z de Cierre... 🖨️')),
                      );
                    },
                    icon: const Icon(Icons.print, size: 28),
                    label: const Text('IMPRIMIR CORTE DE CAJA (Z)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      elevation: 5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}