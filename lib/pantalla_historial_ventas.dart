import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/venta.dart';
import 'services/api_service.dart';
import 'main.dart'; // Archivo principal donde está PantallaInventario
import 'pantalla_caja.dart';
import 'pantalla_corte_caja.dart';

class PantallaHistorialVentas extends StatefulWidget {
  const PantallaHistorialVentas({super.key});

  @override
  State<PantallaHistorialVentas> createState() => _PantallaHistorialVentasState();
}

class _PantallaHistorialVentasState extends State<PantallaHistorialVentas> {
  final ApiService apiService = ApiService();

  final FocusNode _mainFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Venta> _ventasActuales = [];
  bool _cargando = true;

  // 🔥 SISTEMA DE NAVEGACIÓN 2D SIMPLIFICADO 🔥
  // -1 = Menú Hamburguesa
  //  0 a N = Lista de ventas
  int _elementoActivo = 0; 

  @override
  void initState() {
    super.initState();
    _cargarVentas();
    Future.delayed(Duration.zero, () => _mainFocusNode.requestFocus());
  }

  void _cargarVentas() async {
    setState(() => _cargando = true);
    try {
      final ventas = await apiService.obtenerVentas();
      setState(() {
        // Ordenamos las ventas para que las más recientes salgan arriba
        ventas.sort((a, b) => (b.fecha ?? DateTime.now()).compareTo(a.fecha ?? DateTime.now()));
        _ventasActuales = ventas;
        _cargando = false;
        
        // Ajustar el foco si la lista se actualiza
        if (_ventasActuales.isEmpty) {
          _elementoActivo = -1; // Al menú si no hay ventas
        } else if (_elementoActivo >= _ventasActuales.length) {
          _elementoActivo = _ventasActuales.length - 1;
        } else if (_elementoActivo == -1 && _ventasActuales.isNotEmpty) {
          _elementoActivo = 0;
        }
      });
    } catch (e) {
      setState(() => _cargando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar historial: $e')));
      }
    }
  }

  void _setElementoActivo(int nuevo) {
    setState(() => _elementoActivo = nuevo);
  }

  void _manejarTeclas(KeyEvent event) {
    if (event is KeyDownEvent) {
      // ALT + M: Abrir Menú Hamburguesa
      if (HardwareKeyboard.instance.isAltPressed && event.logicalKey == LogicalKeyboardKey.keyM) {
        _scaffoldKey.currentState?.openDrawer();
        return;
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_elementoActivo == -1 && _ventasActuales.isNotEmpty) {
          _setElementoActivo(0);
          _hacerScrollHaciaItem();
        } else if (_elementoActivo >= 0 && _elementoActivo < _ventasActuales.length - 1) {
          _setElementoActivo(_elementoActivo + 1);
          _hacerScrollHaciaItem();
        }
      }
      else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_elementoActivo > 0) {
          _setElementoActivo(_elementoActivo - 1);
          _hacerScrollHaciaItem();
        } else if (_elementoActivo == 0) {
          _setElementoActivo(-1); // Sube al menú
        }
      }
      else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        if (_elementoActivo == -1) {
          _scaffoldKey.currentState?.openDrawer();
        } else if (_elementoActivo >= 0 && _elementoActivo < _ventasActuales.length) {
          _mostrarDetalleVenta(_ventasActuales[_elementoActivo]);
        }
      }
      else if (event.logicalKey == LogicalKeyboardKey.delete) {
        if (_elementoActivo >= 0 && _elementoActivo < _ventasActuales.length) {
          final venta = _ventasActuales[_elementoActivo];
          if (venta.estado == 'CANCELADA') {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Esta venta ya está anulada.')));
          } else {
            _mostrarConfirmacionAnular(venta);
          }
        }
      }
    }
  }

  // 🔥 LÓGICA DE SCROLL: Centra el elemento en la pantalla
  void _hacerScrollHaciaItem() {
    if (_ventasActuales.isEmpty || _elementoActivo < 0 || !_scrollController.hasClients) return;
    
    // Lo aumentamos un poco a 100 por los títulos de fecha
    double alturaAproximadaItem = 100.0; 
    double posicionDeseada = _elementoActivo * alturaAproximadaItem;
    
    double alturaPantalla = _scrollController.position.viewportDimension;
    double offset = posicionDeseada - (alturaPantalla / 2) + (alturaAproximadaItem / 2);
    
    if (offset < 0) offset = 0;
    if (offset > _scrollController.position.maxScrollExtent) {
      offset = _scrollController.position.maxScrollExtent;
    }
    
    _scrollController.animateTo(offset, duration: const Duration(milliseconds: 150), curve: Curves.easeInOut);
  }

  // 🔥 NUEVA FUNCIÓN: Para formatear la fecha bonito 🔥
  String _formatearFechaTexto(DateTime fecha) {
    List<String> meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return "${fecha.day} de ${meses[fecha.month - 1]} de ${fecha.year}";
  }

  void _mostrarDetalleVenta(Venta venta) {
    bool estaAnulada = venta.estado == 'CANCELADA';
    
    String fechaStr = venta.fecha != null 
        ? "${venta.fecha!.day.toString().padLeft(2, '0')}/${venta.fecha!.month.toString().padLeft(2, '0')}/${venta.fecha!.year} ${venta.fecha!.hour.toString().padLeft(2, '0')}:${venta.fecha!.minute.toString().padLeft(2, '0')}"
        : "Sin fecha";

    showDialog(
      context: context,
      builder: (context) {
        return Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.escape || event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
              Navigator.pop(context);
              _mainFocusNode.requestFocus();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: AlertDialog(
            title: Text(estaAnulada ? 'Venta #${venta.id} (ANULADA) 🚫' : 'Detalle de Venta #${venta.id} 🧾'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📅 Fecha: $fechaStr', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('💰 Total: \$${venta.total.toStringAsFixed(0)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: estaAnulada ? Colors.red : Colors.green)),
                    const SizedBox(height: 10),
                    
                    const Text('MÉTODOS DE PAGO:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    if (venta.pagos != null && venta.pagos!.isNotEmpty)
                      ...venta.pagos!.map((p) => Text('💳 ${p.metodoPago.name.toUpperCase()}: \$${p.monto.toStringAsFixed(0)}')).toList()
                    else
                      const Text('No registrado'),
                    
                    const Divider(thickness: 2),
                    
                    const Text('PRODUCTOS VENDIDOS:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const SizedBox(height: 5),
                    if (venta.detalles.isNotEmpty)
                      ...venta.detalles.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text('${d.cantidad}x ${d.producto.nombre}')),
                            Text('\$${(d.precioAplicado ?? d.producto.precioVenta * d.cantidad).toStringAsFixed(0)}'),
                          ],
                        ),
                      )).toList()
                    else
                      const Text('No hay detalles registrados.', style: TextStyle(fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _mainFocusNode.requestFocus();
                },
                child: const Text('Cerrar (Enter)'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarConfirmacionAnular(Venta venta) {
    int botonSeleccionado = 1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.arrowRight) {
                    setStateDialog(() => botonSeleccionado = botonSeleccionado == 0 ? 1 : 0);
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                    Navigator.pop(context);
                    if (botonSeleccionado == 1) _anularVenta(venta);
                    _mainFocusNode.requestFocus();
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
                title: const Text('Anular Venta 🚫', style: TextStyle(color: Colors.red)),
                content: Text('¿Seguro que deseas ANULAR la venta #${venta.id} por \$${venta.total.toStringAsFixed(0)}?\n\n(Esta acción devolverá el stock a los productos)'),
                actions: [
                  Container(
                    decoration: botonSeleccionado == 0 ? BoxDecoration(border: Border.all(color: Colors.grey, width: 2), borderRadius: BorderRadius.circular(8)) : null,
                    child: TextButton(
                      onPressed: () { Navigator.pop(context); _mainFocusNode.requestFocus(); },
                      child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  Container(
                    decoration: botonSeleccionado == 1 ? BoxDecoration(border: Border.all(color: Colors.red, width: 3), borderRadius: BorderRadius.circular(20)) : null,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: botonSeleccionado == 1 ? Colors.red : Colors.red.shade300, foregroundColor: Colors.white),
                      onPressed: () { Navigator.pop(context); _anularVenta(venta); _mainFocusNode.requestFocus(); },
                      child: const Text('Anular Venta'),
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

  void _anularVenta(Venta venta) async {
    try {
      await apiService.eliminarVenta(venta.id.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Petición de anulación enviada'), backgroundColor: Colors.green));
      }
      _cargarVentas(); // Recargamos para ver si el backend la borró o la actualizó
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error al anular: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              color: _elementoActivo == -1 ? Colors.white.withOpacity(0.4) : Colors.transparent,
              borderRadius: BorderRadius.circular(8)
            ),
            child: IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ),
          title: const Text('Historial de Ventas 🧾', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: Colors.blueGrey,
          actions: [
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _cargarVentas),
          ],
        ),
        
        drawer: MenuLateralMagico(alCerrar: () => _mainFocusNode.requestFocus(), indiceActual: 2),

        body: Column(
          children: [
            const SizedBox(height: 10), // Un pequeño respiro arriba
            Expanded(
              child: _cargando 
                ? const Center(child: CircularProgressIndicator())
                : _ventasActuales.isEmpty 
                  ? const Center(child: Text('No hay ventas registradas.', style: TextStyle(fontSize: 18)))
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _ventasActuales.length,
                      itemBuilder: (context, index) {
                        final venta = _ventasActuales[index];
                        final bool estaSeleccionado = _elementoActivo == index;
                        final bool estaAnulada = venta.estado == 'CANCELADA';

                        String horaStr = venta.fecha != null 
                            ? "${venta.fecha!.hour.toString().padLeft(2, '0')}:${venta.fecha!.minute.toString().padLeft(2, '0')}"
                            : "";

                        // 🔥 LÓGICA DE SEPARADORES POR FECHA 🔥
                        bool mostrarSeparador = false;
                        if (index == 0) {
                          mostrarSeparador = true;
                        } else {
                          final ventaAnterior = _ventasActuales[index - 1];
                          if (venta.fecha != null && ventaAnterior.fecha != null) {
                            if (venta.fecha!.day != ventaAnterior.fecha!.day || 
                                venta.fecha!.month != ventaAnterior.fecha!.month || 
                                venta.fecha!.year != ventaAnterior.fecha!.year) {
                              mostrarSeparador = true;
                            }
                          }
                        }

                        // Generamos el diseño de la tarjeta
                        Widget tarjetaVenta = Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          color: estaSeleccionado 
                            ? (estaAnulada ? Colors.red.shade50 : Colors.blueGrey.shade50) 
                            : (estaAnulada ? Colors.grey.shade100 : Colors.white),
                          shape: estaSeleccionado 
                            ? RoundedRectangleBorder(side: BorderSide(color: estaAnulada ? Colors.red : Colors.blueGrey, width: 2), borderRadius: BorderRadius.circular(10)) 
                            : null,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: estaAnulada ? Colors.red.shade200 : (estaSeleccionado ? Colors.blueGrey : Colors.grey.shade400),
                              child: Icon(estaAnulada ? Icons.block : Icons.receipt_long, color: Colors.white)
                            ),
                            title: Text(
                              'Venta #${venta.id} - $horaStr', 
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                decoration: estaAnulada ? TextDecoration.lineThrough : null,
                                color: estaAnulada ? Colors.grey : Colors.black
                              )
                            ),
                            subtitle: Text(estaAnulada ? 'Esta venta fue anulada' : 'Presiona Enter para ver detalles'), 
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '\$${venta.total.toStringAsFixed(0)}', 
                                  style: TextStyle(
                                    fontSize: 18, 
                                    color: estaAnulada ? Colors.grey : Colors.green, 
                                    fontWeight: FontWeight.bold,
                                    decoration: estaAnulada ? TextDecoration.lineThrough : null,
                                  )
                                ),
                                const SizedBox(width: 10),
                                if (estaSeleccionado && !estaAnulada) const Icon(Icons.delete_outline, color: Colors.red),
                              ],
                            ),
                            onTap: () {
                              _setElementoActivo(index);
                              _mainFocusNode.requestFocus();
                              _mostrarDetalleVenta(venta);
                            },
                          ),
                        );

                        // Si debe llevar separador, agrupamos el título y la tarjeta
                        if (mostrarSeparador && venta.fecha != null) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 20, top: 20, bottom: 5),
                                child: Text(
                                  _formatearFechaTexto(venta.fecha!),
                                  style: TextStyle(
                                    fontSize: 16, 
                                    fontWeight: FontWeight.bold, 
                                    color: Colors.blueGrey.shade700
                                  ),
                                ),
                              ),
                              tarjetaVenta,
                            ],
                          );
                        }

                        // Si no, devolvemos solo la tarjeta normal
                        return tarjetaVenta;
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