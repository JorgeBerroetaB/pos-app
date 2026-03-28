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

  // --- ¡NUEVO WIDGET CORREGIDO! TARJETAS RECTANGULARES Y ANCHAS ---
  Widget _construirTarjetaResumen(String titulo, double monto, IconData icono, Color color) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            // Círculo con el ícono (Izquierda)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 30, color: color),
            ),
            const SizedBox(width: 20),
            
            // Texto del Título (Centro-Izquierda)
            Expanded(
              child: Text(
                titulo, 
                style: const TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.grey
                )
              ),
            ),
            
            // Monto (Derecha)
            Text(
              '\$${monto.toStringAsFixed(0)}', 
              style: TextStyle(
                fontSize: 26, 
                fontWeight: FontWeight.bold, 
                color: color
              )
            ),
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
          
          // 1. Filtrar solo las ventas de HOY
          final hoy = DateTime.now();
          final ventasHoy = todasLasVentas.where((v) => 
            v.fecha.year == hoy.year && v.fecha.month == hoy.month && v.fecha.day == hoy.day
          ).toList();

          // 2. Calcular los totales de hoy
          double totalGeneral = 0;
          double totalEfectivo = 0;
          double totalTarjeta = 0;
          double totalTransferencia = 0;

          for (var venta in ventasHoy) {
            totalGeneral += venta.total;
            if (venta.metodoPago == MetodoPago.efectivo) totalEfectivo += venta.total;
            else if (venta.metodoPago == MetodoPago.tarjeta) totalTarjeta += venta.total;
            else if (venta.metodoPago == MetodoPago.transferencia) totalTransferencia += venta.total;
          }

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Resumen del Día', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text('${hoy.day}/${hoy.month}/${hoy.year} - ${ventasHoy.length} ventas registradas hoy', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 20),

                // --- ¡NUEVO DISEÑO! Listado de 4 tarjetas rectangulares ---
                Expanded(
                  child: ListView(
                    children: [
                      _construirTarjetaResumen('TOTAL VENTAS HOY', totalGeneral, Icons.account_balance_wallet, Colors.blue),
                      _construirTarjetaResumen('EFECTIVO EN CAJA', totalEfectivo, Icons.payments, Colors.green),
                      _construirTarjetaResumen('PAGOS CON TARJETA', totalTarjeta, Icons.credit_card, Colors.orange),
                      _construirTarjetaResumen('TRANSFERENCIAS', totalTransferencia, Icons.sync_alt, Colors.purple),
                      const SizedBox(height: 30), // Espacio extra antes del botón
                    ],
                  ),
                ),

                // Botón de Cierre
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Imprimiendo Ticket Z de Cierre... 🖨️')),
                      );
                      // Aquí luego conectaremos el TicketService para imprimir el cierre real
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