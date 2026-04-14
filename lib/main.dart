import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/producto.dart';
import 'services/api_service.dart';
import 'pantalla_caja.dart'; 
import 'pantalla_corte_caja.dart'; 
import 'pantalla_historial_ventas.dart';
import 'pantalla_facturas.dart';
void main() {
  runApp(const YupiPosApp());
}


class YupiPosApp extends StatelessWidget {
  const YupiPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pingu POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const PantallaInventario(),
    );
  }
}

class PantallaInventario extends StatefulWidget {
  const PantallaInventario({super.key});

  @override
  State<PantallaInventario> createState() => _PantallaInventarioState();
}

class _PantallaInventarioState extends State<PantallaInventario> {
  final ApiService apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _mainFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(); 
  
  Future<List<Producto>>? _productosFuture;
  List<Producto> _productosActuales = []; 
  
  // 🔥 SISTEMA DE NAVEGACIÓN 2D 🔥
  // -4 = Menú Hamburguesa
  // -3 = Buscador
  // -2 = Botón Buscar
  // -1 = Botón Nuevo Producto
  //  0 a N = Lista de productos
  int _elementoActivo = -3; 

  @override
  void initState() {
    super.initState();
    _cargarTodosLosProductos();
    Future.delayed(Duration.zero, () {
      _setElementoActivo(-3);
    });
  }

  void _cargarTodosLosProductos() {
    setState(() {
      _productosFuture = apiService.obtenerTodos().then((productos) {
        final productosFiltrados = productos.where((p) => p.sku.trim().isNotEmpty).toList();
        _productosActuales = productosFiltrados;
        return productosFiltrados;
      });
    });
  }

  void _buscarProducto() {
    String termino = _searchController.text.trim();
    if (termino.isEmpty) {
      _cargarTodosLosProductos();
      return;
    }
    setState(() {
      _productosFuture = apiService.buscarProductos(termino).then((productos) {
        _productosActuales = productos;
        return productos;
      });
    });
  }

  void _setElementoActivo(int nuevo) {
    setState(() => _elementoActivo = nuevo);
    if (nuevo == -3) {
      _searchFocusNode.requestFocus();
    } else {
      if (_searchFocusNode.hasFocus) _searchFocusNode.unfocus();
      _mainFocusNode.requestFocus();
    }
  }

  bool _manejarTeclas(KeyEvent event) {
    if (event is KeyDownEvent) {
      // 🔥 REGLA DE ORO MEJORADA: 
      // Si el buscador tiene el foco, le permitimos salir hacia arriba o la derecha.
      if (_searchFocusNode.hasFocus) {
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          if (_productosActuales.isNotEmpty) _setElementoActivo(0);
          return true;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _setElementoActivo(-4); // Sube a la hamburguesa
          return true;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _setElementoActivo(-2); // Se mueve al botón de Buscar
          return true;
        } else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          _buscarProducto();
          _setElementoActivo(0);
          return true;
        } else if (event.logicalKey == LogicalKeyboardKey.escape) {
          _searchController.clear();
          _buscarProducto();
          return true;
        }
        // Para letras y números, ignoramos y dejamos que escriba.
        return false;
      }

      // --- ATAJOS GLOBALES CUANDO EL BUSCADOR NO TIENE EL FOCO ---
      if (HardwareKeyboard.instance.isAltPressed) {
        if (event.logicalKey == LogicalKeyboardKey.keyN) {
          _mostrarFormulario();
          return true;
        } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
          _scaffoldKey.currentState?.openDrawer();
          return true;
        }
      }

      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _searchController.clear();
        _buscarProducto();
        _setElementoActivo(-3);
        return true;
      }
      else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_elementoActivo == -4) {
          _setElementoActivo(-3); 
        } else if (_elementoActivo >= -3 && _elementoActivo <= -1) {
          if (_productosActuales.isNotEmpty) _setElementoActivo(0); 
        } else if (_elementoActivo >= 0 && _elementoActivo < _productosActuales.length - 1) {
          _setElementoActivo(_elementoActivo + 1);
          _hacerScrollHaciaItem();
        }
        return true;
      }
      else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_elementoActivo > 0) {
          _setElementoActivo(_elementoActivo - 1);
          _hacerScrollHaciaItem();
        } else if (_elementoActivo == 0) {
          _setElementoActivo(-3); 
        } else if (_elementoActivo >= -3 && _elementoActivo <= -1) {
          _setElementoActivo(-4); 
        }
        return true;
      }
      else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (_elementoActivo == -3) _setElementoActivo(-2);
        else if (_elementoActivo == -2) _setElementoActivo(-1);
        return true;
      }
      else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (_elementoActivo == -1) _setElementoActivo(-2);
        else if (_elementoActivo == -2) _setElementoActivo(-3);
        return true;
      }
      else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        if (_elementoActivo == -4) {
          _scaffoldKey.currentState?.openDrawer();
        } else if (_elementoActivo == -2) {
          _buscarProducto();
          _setElementoActivo(0); 
        } else if (_elementoActivo == -1) {
          _mostrarFormulario();
        } else if (_elementoActivo >= 0 && _elementoActivo < _productosActuales.length) {
          _mostrarFormulario(productoExistente: _productosActuales[_elementoActivo]);
        }
        return true;
      }
      else if (event.logicalKey == LogicalKeyboardKey.delete) {
        if (_elementoActivo >= 0 && _elementoActivo < _productosActuales.length) {
          _mostrarConfirmacionEliminar(_productosActuales[_elementoActivo]);
          return true;
        }
      }
    }
    return false;
  }

  void _hacerScrollHaciaItem() {
    double posicion = _elementoActivo * 80.0; 
    _scrollController.animateTo(posicion, duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
  }

  void _eliminar(String sku) async {
    if (sku.trim().isEmpty) return;
    try {
      await apiService.eliminarProducto(sku);
      _cargarTodosLosProductos();
      if (_elementoActivo >= _productosActuales.length - 1) {
        _setElementoActivo(_productosActuales.length - 2 >= 0 ? _productosActuales.length - 2 : -3);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error al eliminar: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _mostrarConfirmacionEliminar(Producto producto) {
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
                    if (botonSeleccionado == 1) _eliminar(producto.sku);
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
                title: const Text('Eliminar Producto 🗑️', style: TextStyle(color: Colors.red)),
                content: Text('¿Estás seguro de que deseas eliminar "${producto.nombre}"?\n\n(Usa ⬅️ ➡️ para moverte y Enter para seleccionar)'),
                actions: [
                  Container(
                    decoration: botonSeleccionado == 0 ? BoxDecoration(border: Border.all(color: Colors.grey, width: 2), borderRadius: BorderRadius.circular(8)) : null,
                    child: TextButton(onPressed: () { Navigator.pop(context); _mainFocusNode.requestFocus(); }, child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
                  ),
                  Container(
                    decoration: botonSeleccionado == 1 ? BoxDecoration(border: Border.all(color: Colors.red, width: 3), borderRadius: BorderRadius.circular(20)) : null,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: botonSeleccionado == 1 ? Colors.red : Colors.red.shade300, foregroundColor: Colors.white),
                      onPressed: () { Navigator.pop(context); _eliminar(producto.sku); _mainFocusNode.requestFocus(); },
                      child: const Text('Eliminar'),
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

  void _mostrarFormulario({Producto? productoExistente}) {
    final bool esEdicion = productoExistente != null;
    final skuController = TextEditingController(text: productoExistente?.sku ?? '');
    final nombreController = TextEditingController(text: productoExistente?.nombre ?? '');
    final precioVentaController = TextEditingController(text: productoExistente?.precioVenta.toString() ?? '');
    final precioCostoController = TextEditingController(text: productoExistente?.precioCosto.toString() ?? '');
    final stockController = TextEditingController(text: productoExistente?.stock.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                FocusScope.of(context).nextFocus();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                FocusScope.of(context).previousFocus();
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
            title: Text(esEdicion ? 'Editar Producto ✏️' : 'Nuevo Producto 📦'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: skuController, autofocus: !esEdicion, decoration: const InputDecoration(labelText: 'Código de Barras (SKU) *Obligatorio'), enabled: !esEdicion, textInputAction: TextInputAction.next, onSubmitted: (_) => FocusScope.of(context).nextFocus()),
                  TextField(controller: nombreController, autofocus: esEdicion, decoration: const InputDecoration(labelText: 'Nombre del Producto *Obligatorio'), textInputAction: TextInputAction.next, onSubmitted: (_) => FocusScope.of(context).nextFocus()),
                  TextField(controller: precioVentaController, decoration: const InputDecoration(labelText: 'Precio de Venta (\$)'), keyboardType: TextInputType.number, textInputAction: TextInputAction.next, onSubmitted: (_) => FocusScope.of(context).nextFocus()),
                  TextField(controller: precioCostoController, decoration: const InputDecoration(labelText: 'Precio de Costo (\$)'), keyboardType: TextInputType.number, textInputAction: TextInputAction.next, onSubmitted: (_) => FocusScope.of(context).nextFocus()),
                  TextField(controller: stockController, decoration: const InputDecoration(labelText: 'Unidades en Stock'), keyboardType: TextInputType.number, textInputAction: TextInputAction.next, onSubmitted: (_) => FocusScope.of(context).nextFocus()),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () { Navigator.pop(context); _mainFocusNode.requestFocus(); }, child: const Text('Cancelar', style: TextStyle(color: Colors.red))),
              ElevatedButton(
                onPressed: () async {
                  final sku = skuController.text.trim();
                  final nombre = nombreController.text.trim();
                  if (sku.isEmpty || nombre.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Ingresa SKU y Nombre.'), backgroundColor: Colors.red));
                    return;
                  }
                  final nuevo = Producto(sku: sku, nombre: nombre, precioVenta: double.tryParse(precioVentaController.text) ?? 0.0, precioCosto: double.tryParse(precioCostoController.text) ?? 0.0, stock: int.tryParse(stockController.text) ?? 0);
                  esEdicion ? await apiService.actualizarProducto(nuevo.sku, nuevo) : await apiService.crearProducto(nuevo);
                  if (mounted) { Navigator.pop(context); _cargarTodosLosProductos(); _mainFocusNode.requestFocus(); }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                child: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _mainFocusNode,
      onKeyEvent: (node, event) {
        bool manejado = _manejarTeclas(event);
        return manejado ? KeyEventResult.handled : KeyEventResult.ignored;
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          leading: Container(
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: _elementoActivo == -4 ? Colors.white.withOpacity(0.4) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
            child: IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
          ),
          title: const Text('Pingu POS 🐧 - Inventario', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: Colors.blueAccent,

          actions: [
            // 🌟 ESTE ES TU NUEVO BOTÓN DE FACTURAS 🌟
            IconButton(
              icon: const Icon(Icons.receipt_long, color: Colors.white),
              tooltip: 'Subir Factura XML',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PantallaFacturas()),
                );
              },
            ),
            // ESTE ES TU BOTÓN ORIGINAL DE ACTUALIZAR
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white), 
              onPressed: _cargarTodosLosProductos
            ),
          ],

        ),
        drawer: MenuLateralMagico(alCerrar: () => _setElementoActivo(-3)),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(border: _elementoActivo == -3 ? Border.all(color: Colors.blueAccent, width: 3) : null, borderRadius: BorderRadius.circular(10)),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        decoration: InputDecoration(hintText: 'Buscar (Esc para limpiar)...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                        onTap: () => _setElementoActivo(-3),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) { _buscarProducto(); _setElementoActivo(0); },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () { _buscarProducto(); _setElementoActivo(0); },
                    style: ElevatedButton.styleFrom(backgroundColor: _elementoActivo == -2 ? Colors.amber : Colors.blueGrey.shade100, foregroundColor: _elementoActivo == -2 ? Colors.black : Colors.black87, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), side: _elementoActivo == -2 ? const BorderSide(color: Colors.black, width: 2) : null),
                    child: const Text('Buscar', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _mostrarFormulario(),
                    icon: const Icon(Icons.add),
                    label: const Text('Nuevo (Alt+N)'),
                    style: ElevatedButton.styleFrom(backgroundColor: _elementoActivo == -1 ? Colors.greenAccent : Colors.blueAccent, foregroundColor: _elementoActivo == -1 ? Colors.black : Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), side: _elementoActivo == -1 ? const BorderSide(color: Colors.black, width: 2) : null),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Producto>>(
                future: _productosFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No hay productos.'));
                  final productos = snapshot.data!;
                  return ListView.builder(
                    controller: _scrollController, 
                    itemCount: productos.length,
                    itemBuilder: (context, index) {
                      final producto = productos[index];
                      final bool estaSeleccionado = _elementoActivo == index;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: estaSeleccionado ? Colors.blue.shade50 : Colors.white,
                        shape: estaSeleccionado ? RoundedRectangleBorder(side: const BorderSide(color: Colors.blueAccent, width: 2), borderRadius: BorderRadius.circular(10)) : null,
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: estaSeleccionado ? Colors.blue : Colors.blueGrey, child: const Icon(Icons.inventory_2, color: Colors.white)),
                          title: Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('SKU: ${producto.sku} | Stock: ${producto.stock} | Costo: \$${producto.precioCosto}'),
                          trailing: Text('\$${producto.precioVenta.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
                          onTap: () { _setElementoActivo(index); _mostrarFormulario(productoExistente: producto); },
                        ),
                      );
                    },
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
  const MenuLateralMagico({super.key, required this.alCerrar});
  @override
  State<MenuLateralMagico> createState() => _MenuLateralMagicoState();
}

class _MenuLateralMagicoState extends State<MenuLateralMagico> {
  int _itemDrawerSeleccionado = 0; 
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
    Future.delayed(Duration.zero, () => _drawerFocus.requestFocus());
  }

  void _ejecutarAccion(BuildContext context) {
    Navigator.pop(context); 
    if (_itemDrawerSeleccionado == 1) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PantallaCaja()));
    } else if (_itemDrawerSeleccionado == 2) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PantallaHistorialVentas()));
    } else if (_itemDrawerSeleccionado == 3) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PantallaCorteCaja()));
    } else {
      widget.alCerrar(); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Focus(
        focusNode: _drawerFocus,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowDown && _itemDrawerSeleccionado < _opciones.length - 1) {
              setState(() => _itemDrawerSeleccionado++);
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp && _itemDrawerSeleccionado > 0) {
              setState(() => _itemDrawerSeleccionado--);
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
              decoration: BoxDecoration(color: Colors.blueAccent),
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
                color: estaResaltado ? Colors.grey.shade200 : Colors.transparent,
                child: ListTile(
                  leading: Icon(opcion['icono'], color: opcion['color']),
                  title: Text(opcion['titulo'], style: TextStyle(fontSize: 16, fontWeight: estaResaltado ? FontWeight.bold : FontWeight.normal)),
                  trailing: estaResaltado ? const Icon(Icons.keyboard_return, size: 16, color: Colors.grey) : null,
                  onTap: () { setState(() => _itemDrawerSeleccionado = index); _ejecutarAccion(context); },
                ),
              );
            })
          ],
        ),
      ),
    );
  }

  
}