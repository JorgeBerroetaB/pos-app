import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/venta.dart';
import 'models/metodo_pago.dart';
import 'services/api_service.dart';
import 'main.dart'; // Para el menú
import 'pantalla_caja.dart'; // Para el menú
import 'pantalla_historial_ventas.dart'; // Para saltar al historial

class PantallaCorteCaja extends StatefulWidget {
  const PantallaCorteCaja({super.key});

  @override
  State<PantallaCorteCaja> createState() => _PantallaCorteCajaState();
}

class _PantallaCorteCajaState extends State<PantallaCorteCaja> {
  final ApiService apiService = ApiService();
  
  final FocusNode _mainFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _cargando = true;
  List<Venta> _ventasDeHoy = [];

  // 🔥 SISTEMA DE NAVEGACIÓN 2D 🔥
  // -2 = Menú Hamburguesa
  // -1 = Botón Imprimir Corte (Z)
  //  0 a N = Lista de ventas del día
  int _elementoActivo = -1; 

  @override
  void initState() {
    super.initState();
    _cargarVentasDeHoy();
    Future.delayed(Duration.zero, () => _mainFocusNode.requestFocus());
  }

  void _cargarVentasDeHoy() async {
    setState(() => _cargando = true);
    try {
      final todasLasVentas = await apiService.obtenerVentas();
      final hoy = DateTime.now();

      // Filtramos solo las ventas del día actual
      final ventasHoy = todasLasVentas.where((v) {
        if (v.fecha == null) return false;
        return v.fecha!.day == hoy.day && v.fecha!.month == hoy.month && v.fecha!.year == hoy.year;
      }).toList();

      // Las ordenamos para que las más recientes salgan arriba
      ventasHoy.sort((a, b) => (b.fecha ?? DateTime.now()).compareTo(a.fecha ?? DateTime.now()));

      setState(() {
        _ventasDeHoy = ventasHoy;
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar ventas: $e')));
      }
    }
  }

  void _manejarTeclas(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (HardwareKeyboard.instance.isAltPressed && event.logicalKey == LogicalKeyboardKey.keyM) {
        _scaffoldKey.currentState?.openDrawer();
        return;
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_elementoActivo < _ventasDeHoy.length - 1) {
          setState(() => _elementoActivo++);
          _hacerScrollHaciaItem();
        }
      }
      else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_elementoActivo > -2) {
          setState(() => _elementoActivo--);
          _hacerScrollHaciaItem();
        }
      }
      else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        if (_elementoActivo == -2) {
          _scaffoldKey.currentState?.openDrawer();
        } else if (_elementoActivo == -1) {
          _imprimirCorte();
        } else if (_elementoActivo >= 0 && _elementoActivo < _ventasDeHoy.length) {
          _mostrarResumenVentaPopup(_ventasDeHoy[_elementoActivo]);
        }
      }
    }
  }

  void _hacerScrollHaciaItem() {
    if (_elementoActivo < 0 || !_scrollController.hasClients) return;
    double posicion = _elementoActivo * 80.0;
    _scrollController.animateTo(posicion, duration: const Duration(milliseconds: 150), curve: Curves.easeInOut);
  }

  void _imprimirCorte() {
    // Aquí a futuro llamaremos a TicketService().imprimirCorteZ(...)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🖨️ Mandando resumen del día a la impresora...'), backgroundColor: Colors.purple),
    );
  }

  // 🔥 NUEVO: Popup al dar Enter en una venta desde el Cierre de Caja
  void _mostrarResumenVentaPopup(Venta venta) {
    bool estaAnulada = venta.estado == 'CANCELADA';
    String horaStr = venta.fecha != null ? "${venta.fecha!.hour.toString().padLeft(2, '0')}:${venta.fecha!.minute.toString().padLeft(2, '0')}" : "";

    showDialog(
      context: context,
      builder: (context) {
        int botonSel = 0; // 0 = Cerrar, 1 = Investigar en Historial
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.arrowRight) {
                    setStateDialog(() => botonSel = botonSel == 0 ? 1 : 0);
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                    Navigator.pop(context);
                    if (botonSel == 1) {
                      // 🚀 SALTO AL HISTORIAL
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PantallaHistorialVentas()));
                    } else {
                      _mainFocusNode.requestFocus();
                    }
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                    Navigator.pop(context);
                    _mainFocusNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: AlertDialog(
                title: Text(estaAnulada ? '⚠️ Venta Anulada ($horaStr)' : 'Resumen Venta #${venta.id} 💵'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total: \$${venta.total.toStringAsFixed(0)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: estaAnulada ? Colors.red : Colors.green)),
                    const SizedBox(height: 5),
                    Text('Hora: $horaStr', style: const TextStyle(color: Colors.grey)),
                    const Divider(),
                    const Text('Artículos principales:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const SizedBox(height: 5),
                    // Mostramos solo los primeros 3 para que sea un resumen rápido
                    ...venta.detalles.take(3).map((d) => Text('• ${d.cantidad}x ${d.producto.nombre}')),
                    if (venta.detalles.length > 3) 
                      Text('• ... y ${venta.detalles.length - 3} artículos más', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                  ],
                ),
                actions: [
                  Container(
                    decoration: botonSel == 0 ? BoxDecoration(border: Border.all(color: Colors.grey, width: 2), borderRadius: BorderRadius.circular(8)) : null,
                    child: TextButton(onPressed: () { Navigator.pop(context); _mainFocusNode.requestFocus(); }, child: const Text('Cerrar', style: TextStyle(color: Colors.grey))),
                  ),
                  Container(
                    decoration: botonSel == 1 ? BoxDecoration(border: Border.all(color: Colors.red, width: 3), borderRadius: BorderRadius.circular(20)) : null,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: botonSel == 1 ? Colors.red : Colors.red.shade300, foregroundColor: Colors.white),
                      icon: const Icon(Icons.search),
                      label: const Text('Investigar en Historial'),
                      onPressed: () {
                        Navigator.pop(context);
                        // 🚀 SALTO AL HISTORIAL
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PantallaHistorialVentas()));
                      },
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _construirTarjetaResumen(String titulo, double monto, IconData icono, Color color) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12), 
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), 
              child: Icon(icono, size: 28, color: color)
            ),
            const SizedBox(width: 15),
            Expanded(child: Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey))),
            Text('\$${monto.toStringAsFixed(0)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    double totalGeneral = 0;
    double totalEfectivo = 0;
    double totalTarjeta = 0;
    double totalTransferencia = 0;
    double totalCancelado = 0;
    int cantidadCanceladas = 0;
    int cantidadCompletadas = 0;

    for (var venta in _ventasDeHoy) {
      if (venta.estado == 'CANCELADA') {
        totalCancelado += venta.total;
        cantidadCanceladas++;
        continue;
      }
      
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

    final hoy = DateTime.now();

    return Focus(
      autofocus: true,
      focusNode: _mainFocusNode,
      onKeyEvent: (node, event) {
        _manejarTeclas(event);
        return KeyEventResult.handled;
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          leading: Container(
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _elementoActivo == -2 ? Colors.white.withOpacity(0.4) : Colors.transparent, 
              borderRadius: BorderRadius.circular(8)
            ),
            child: IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
          ),
          title: const Text('Corte de Caja Diario 📊', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.blueGrey,
          actions: [
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _cargarVentasDeHoy),
          ],
        ),
        drawer: MenuLateralMagico(alCerrar: () => _mainFocusNode.requestFocus(), indiceActual: 3),
        backgroundColor: Colors.grey[200],
        body: Column(
          children: [
            // PANEL SUPERIOR: RESUMEN DEL DÍA
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Resumen de Hoy', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        Text('${hoy.day}/${hoy.month}/${hoy.year}', style: const TextStyle(fontSize: 18, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Text('$cantidadCompletadas ventas exitosas | $cantidadCanceladas anuladas', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  ),
                  const SizedBox(height: 10),
                  
                  // Tarjetas
                  _construirTarjetaResumen('TOTAL INGRESOS HOY', totalGeneral, Icons.account_balance_wallet, Colors.blue),
                  Row(
                    children: [
                      Expanded(child: _construirTarjetaResumen('Efectivo', totalEfectivo, Icons.payments, Colors.green)),
                      Expanded(child: _construirTarjetaResumen('Tarjeta/Transf', totalTarjeta + totalTransferencia, Icons.credit_card, Colors.orange)),
                    ],
                  ),
                  if (totalCancelado > 0)
                    _construirTarjetaResumen('VENTAS ANULADAS (No suman)', totalCancelado, Icons.block, Colors.red),
                ],
              ),
            ),

            // BOTÓN IMPRIMIR CORTE
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: _imprimirCorte,
                  icon: const Icon(Icons.print, size: 28),
                  label: const Text('IMPRIMIR CORTE DE CAJA (Z)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _elementoActivo == -1 ? Colors.redAccent.shade100 : Colors.redAccent,
                    foregroundColor: Colors.white,
                    elevation: _elementoActivo == -1 ? 0 : 5,
                    side: _elementoActivo == -1 ? const BorderSide(color: Colors.black, width: 3) : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                  ),
                ),
              ),
            ),

            // LISTA DE VENTAS DEL DÍA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: const [
                  Icon(Icons.list_alt, color: Colors.grey),
                  SizedBox(width: 8),
                  Text("Detalle de Ventas de Hoy", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
                ],
              ),
            ),
            Expanded(
              child: _ventasDeHoy.isEmpty 
                ? const Center(child: Text("No hay ventas registradas hoy.", style: TextStyle(fontSize: 16, color: Colors.grey)))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _ventasDeHoy.length,
                    itemBuilder: (context, index) {
                      final venta = _ventasDeHoy[index];
                      final bool seleccionado = _elementoActivo == index;
                      final bool anulada = venta.estado == 'CANCELADA';
                      
                      String horaStr = venta.fecha != null ? "${venta.fecha!.hour.toString().padLeft(2, '0')}:${venta.fecha!.minute.toString().padLeft(2, '0')}" : "";

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: seleccionado ? Colors.blueGrey.withOpacity(0.2) : Colors.white,
                          border: seleccionado ? Border.all(color: Colors.blueGrey, width: 2) : Border.all(color: Colors.transparent, width: 2),
                          borderRadius: BorderRadius.circular(8)
                        ),
                        child: ListTile(
                          leading: Icon(anulada ? Icons.block : Icons.receipt, color: anulada ? Colors.red : Colors.blueGrey),
                          title: Text("Venta #${venta.id} - $horaStr", style: TextStyle(fontWeight: FontWeight.bold, decoration: anulada ? TextDecoration.lineThrough : null, color: anulada ? Colors.grey : Colors.black)),
                          subtitle: Text(anulada ? "Anulada" : "Presiona Enter para ver resumen"),
                          trailing: Text("\$${venta.total.toStringAsFixed(0)}", style: TextStyle(fontSize: 16, color: anulada ? Colors.grey : Colors.green, fontWeight: FontWeight.bold)),
                          onTap: () {
                            setState(() => _elementoActivo = index);
                            _mainFocusNode.requestFocus();
                            _mostrarResumenVentaPopup(venta);
                          },
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// 🔥 WIDGET: MENÚ LATERAL MAGICO CON TECLADO 🔥
// =======================================================
class MenuLateralMagico extends StatefulWidget {
  final VoidCallback alCerrar;
  final int indiceActual;
  
  const MenuLateralMagico({super.key, required this.alCerrar, this.indiceActual = 0});

  @override
  State<MenuLateralMagico> createState() => _MenuLateralMagicoState();
}

class _MenuLateralMagicoState extends State<MenuLateralMagico> {
  late int _itemDrawerSeleccionado;
  final FocusNode _drawerFocus = FocusNode();

  final List<Map<String, dynamic>> _opciones = [
    {'titulo': 'Inventario', 'icono': Icons.inventory_2, 'color': Colors.blueAccent},
    {'titulo': 'Caja Registradora', 'icono': Icons.point_of_sale, 'color': Colors.green},
    {'titulo': 'Historial de Ventas', 'icono': Icons.history, 'color': Colors.blueGrey},
    {'titulo': 'Corte de Caja', 'icono': Icons.analytics, 'color': Colors.purple},
  ];

  @override
  void initState() {
    super.initState();
    _itemDrawerSeleccionado = widget.indiceActual;
    Future.delayed(Duration.zero, () => _drawerFocus.requestFocus());
  }

  void _ejecutarAccion(BuildContext context) {
    Navigator.pop(context);
    if (_itemDrawerSeleccionado == widget.indiceActual) {
      widget.alCerrar();
      return;
    }
    
    Widget destino;
    switch (_itemDrawerSeleccionado) {
      case 0: destino = const PantallaInventario(); break; 
      case 1: destino = const PantallaCaja(); break;
      case 2: destino = const PantallaHistorialVentas(); break;
      case 3: destino = const PantallaCorteCaja(); break;
      default: return;
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => destino));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Focus(
        focusNode: _drawerFocus,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              if (_itemDrawerSeleccionado < _opciones.length - 1) {
                setState(() => _itemDrawerSeleccionado++);
              }
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              if (_itemDrawerSeleccionado > 0) {
                setState(() => _itemDrawerSeleccionado--);
              }
            } else if (event.logicalKey == LogicalKeyboardKey.enter) {
              _ejecutarAccion(context);
            }
          }
          return KeyEventResult.handled;
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blueGrey),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.storefront, size: 50, color: Colors.white),
                  SizedBox(height: 10),
                  Text('Pingu POS 🐧', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ...List.generate(_opciones.length, (index) {
              final opcion = _opciones[index];
              final bool estaResaltado = _itemDrawerSeleccionado == index;
              return Container(
                color: estaResaltado ? Colors.grey.shade300 : Colors.transparent,
                child: ListTile(
                  leading: Icon(opcion['icono'], color: opcion['color']),
                  title: Text(opcion['titulo'], style: TextStyle(fontSize: 16, fontWeight: estaResaltado ? FontWeight.bold : FontWeight.normal)),
                  trailing: estaResaltado ? const Icon(Icons.keyboard_return, size: 16, color: Colors.grey) : null,
                  onTap: () {
                    setState(() => _itemDrawerSeleccionado = index);
                    _ejecutarAccion(context);
                  },
                ),
              );
            })
          ],
        ),
      ),
    );
  }
}