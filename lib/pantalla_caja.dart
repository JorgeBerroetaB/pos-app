import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/producto.dart';
import 'models/detalle_venta.dart';
import 'models/metodo_pago.dart';
import 'services/api_service.dart';
import 'services/ticket_service.dart';

class PantallaCaja extends StatefulWidget {
  const PantallaCaja({super.key});

  @override
  State<PantallaCaja> createState() => _PantallaCajaState();
}

class _PantallaCajaState extends State<PantallaCaja> {
  final ApiService apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  
  // Nodos de enfoque para no perder el rastro del teclado
  final FocusNode _searchFocusNode = FocusNode(); 
  final FocusNode _rootFocusNode = FocusNode(); 
  
  // Nodos y controlador para la edición de precio inline
  final FocusNode _precioFocusNode = FocusNode();
  final TextEditingController _precioController = TextEditingController();
  int _indiceEditandoPrecio = -1; // -1 significa que no estamos editando nada
  
  List<Producto> _productosBusqueda = []; 
  List<DetalleVenta> _carrito = []; 
  
  // Rastreo de búsqueda
  int _itemBusquedaSeleccionado = -1;

  // Rastreo del carrito para navegar con teclado
  bool _enCarrito = false; 
  int _carritoSeleccionado = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () => _searchFocusNode.requestFocus());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _rootFocusNode.dispose();
    _precioFocusNode.dispose();
    _precioController.dispose();
    super.dispose();
  }

  void _buscarProducto() async {
    if (_productosBusqueda.isNotEmpty && _itemBusquedaSeleccionado >= 0) {
      _agregarAlCarrito(_productosBusqueda[_itemBusquedaSeleccionado]);
      _searchController.clear();
      setState(() {
        _productosBusqueda.clear();
        _itemBusquedaSeleccionado = -1;
      });
      _searchFocusNode.requestFocus();
      return;
    }

    String termino = _searchController.text.trim();
    if (termino.isEmpty) {
      _searchFocusNode.requestFocus();
      return;
    }

    // ==========================================
    // ¡NUEVA MAGIA: DETECTOR DE BALANZAS! ⚖️
    // ==========================================
    // Las balanzas generan un código de 13 dígitos que empieza con 20
    bool esBalanza = termino.length == 13 && termino.startsWith('20');
    String skuBuscado = termino;
    double? precioBalanza;

    if (esBalanza) {
      // 1. Extraemos el SKU (Dígitos del 2 al 7) y quitamos ceros a la izquierda
      String skuExtraido = termino.substring(2, 7);
      skuBuscado = int.parse(skuExtraido).toString(); 
      
      // 2. Extraemos el precio total (Dígitos del 7 al 12)
      precioBalanza = double.tryParse(termino.substring(7, 12));
    }

    try {
      final productoExacto = await apiService.buscarPorSku(skuBuscado);
      if (productoExacto != null) {
        _agregarAlCarrito(productoExacto, precioBalanza: precioBalanza);
        _searchController.clear();
        setState(() {
          _productosBusqueda.clear(); 
          _itemBusquedaSeleccionado = -1;
        });
        _searchFocusNode.requestFocus(); 
        return;
      }

      final resultados = await apiService.buscarProductos(termino);
      setState(() {
        _productosBusqueda = resultados;
        _itemBusquedaSeleccionado = resultados.isNotEmpty ? 0 : -1;
      });
      _searchFocusNode.requestFocus(); 
      
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ¡MODIFICADO! Ahora recibe el precio opcional de la balanza
  void _agregarAlCarrito(Producto producto, {double? precioBalanza}) {
    setState(() {
      if (precioBalanza != null) {
        // Si viene de balanza, lo metemos como un renglón único con su propio precio
        final nuevoDetalle = DetalleVenta(producto: producto, cantidad: 1);
        nuevoDetalle.precioAplicado = precioBalanza;
        _carrito.add(nuevoDetalle);
      } else {
        // Lógica normal: agrupa los productos iguales que NO tengan precios modificados
        int index = _carrito.indexWhere((item) => item.producto.sku == producto.sku && item.precioAplicado == null);
        if (index != -1) {
          _carrito[index].cantidad++;
        } else {
          _carrito.add(DetalleVenta(producto: producto, cantidad: 1));
        }
      }
      _enCarrito = false;
      _indiceEditandoPrecio = -1; // Cancelar edición si agregamos algo
    });
  }

  void _modificarCantidad(int index, int delta) {
    setState(() {
      _carrito[index].cantidad += delta;
      if (_carrito[index].cantidad <= 0) {
        _carrito.removeAt(index);
        
        // Si estábamos editando este ítem o uno inferior, se ajusta
        if (_indiceEditandoPrecio == index) _indiceEditandoPrecio = -1;
        else if (_indiceEditandoPrecio > index) _indiceEditandoPrecio--;

        if (_enCarrito) {
          if (_carrito.isEmpty) {
            _enCarrito = false;
            _searchFocusNode.requestFocus();
          } else if (_carritoSeleccionado > _carrito.length) {
            _carritoSeleccionado = _carrito.length; 
          }
        }
      }
    });
  }

  double get _totalPagar {
    return _carrito.fold(0, (suma, item) => suma + item.subtotal);
  }

  int _aproximarPesoChileno(double total) {
    int totalEntero = total.round();
    int ultimaCifra = totalEntero % 10;
    if (ultimaCifra >= 1 && ultimaCifra <= 5) {
      return totalEntero - ultimaCifra;
    } else if (ultimaCifra >= 6 && ultimaCifra <= 9) {
      return totalEntero + (10 - ultimaCifra);
    } else {
      return totalEntero;
    }
  }

  void _abrirPopupCobro() {
    if (_carrito.isEmpty) return;

    setState(() { _indiceEditandoPrecio = -1; }); // Cierra edición por seguridad

    final double totalActual = _totalPagar;
    final int totalAproximado = _aproximarPesoChileno(totalActual);
    MetodoPago metodoSeleccionado = MetodoPago.efectivo;
    int indiceMetodo = 0; 
    
    final FocusNode popupFocusNode = FocusNode();
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (BuildContext dialogContext) { 
        return StatefulBuilder(
          builder: (BuildContext innerContext, StateSetter setDialogState) {
            
            void cambiarMetodo(int delta) {
              setDialogState(() {
                indiceMetodo = (indiceMetodo + delta) % MetodoPago.values.length;
                if (indiceMetodo < 0) indiceMetodo = MetodoPago.values.length - 1;
                metodoSeleccionado = MetodoPago.values[indiceMetodo];
              });
            }

            void finalizarVenta() async {
              try {
                await apiService.registrarVenta(_carrito, metodoSeleccionado);
                
                if (!dialogContext.mounted) return; 
                Navigator.pop(dialogContext); 

                // Si tienes implementado tu servicio de ticket, se imprimirá aquí
                final ticketService = TicketService();
                await ticketService.imprimirTicket(
                  carrito: List.from(_carrito), 
                  total: totalActual,
                  totalAproximado: totalAproximado,
                  metodoPago: metodoSeleccionado.nombre,
                );

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('¡Venta registrada e imprimiendo! 💰✅'), backgroundColor: Colors.green),
                );
                setState(() {
                  _carrito.clear();
                  _searchController.clear();
                  _productosBusqueda.clear();
                  _itemBusquedaSeleccionado = -1;
                  _enCarrito = false;
                  _carritoSeleccionado = 0;
                });
                _searchFocusNode.requestFocus(); 

              } catch (e) {
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al procesar la venta: $e', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)), 
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 5), 
                  ),
                );
                _searchFocusNode.requestFocus();
              }
            }

            return Focus(
              focusNode: popupFocusNode,
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                   if (event.logicalKey == LogicalKeyboardKey.arrowDown || event.logicalKey == LogicalKeyboardKey.arrowRight) {
                    cambiarMetodo(1);
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowUp || event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    cambiarMetodo(-1);
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                    finalizarVenta(); 
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                    Navigator.pop(dialogContext);
                    _searchFocusNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: AlertDialog(
                title: const Text('Finalizar Venta 🧾', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    const Text('Método de pago', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    
                    Container(
                      width: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green, width: 2), 
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.green.withOpacity(0.1)
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_left, color: Colors.green, size: 30),
                            onPressed: () => cambiarMetodo(-1),
                          ),
                          Text(metodoSeleccionado.nombre.toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                          IconButton(
                            icon: const Icon(Icons.arrow_right, color: Colors.green, size: 30),
                            onPressed: () => cambiarMetodo(1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('(Usa las flechas o Enter)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 30),
                    const Text('TOTAL A PAGAR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text('\$${totalAproximado.toString()}', style: const TextStyle(fontSize: 50, color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
                actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                actions: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _searchFocusNode.requestFocus();
                        },
                        child: const Text('Cancelar (Esc)', style: TextStyle(color: Colors.red, fontSize: 16)),
                      ),
                      ElevatedButton(
                        onPressed: finalizarVenta,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Terminar venta\n(Enter)', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _rootFocusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          
          if (event.logicalKey == LogicalKeyboardKey.f12) {
            if (_carrito.isNotEmpty) _abrirPopupCobro(); 
            return KeyEventResult.handled; 
          } 
          
          if (event.logicalKey == LogicalKeyboardKey.tab) {
            setState(() {
              if (_enCarrito) {
                _enCarrito = false;
                _indiceEditandoPrecio = -1; 
                _searchFocusNode.requestFocus();
              } else {
                if (_carrito.isNotEmpty) {
                  _enCarrito = true;
                  _carritoSeleccionado = 0; 
                  _rootFocusNode.requestFocus();
                }
              }
            });
            return KeyEventResult.handled;
          }

          if (!_enCarrito) {
            // NAVEGACIÓN EN EL BUSCADOR
            if (event.logicalKey == LogicalKeyboardKey.arrowDown && _productosBusqueda.isNotEmpty) {
              setState(() {
                _itemBusquedaSeleccionado = (_itemBusquedaSeleccionado + 1).clamp(0, _productosBusqueda.length - 1);
              });
              return KeyEventResult.handled;
            } 
            else if (event.logicalKey == LogicalKeyboardKey.arrowUp && _productosBusqueda.isNotEmpty) {
              setState(() {
                _itemBusquedaSeleccionado = (_itemBusquedaSeleccionado - 1).clamp(0, _productosBusqueda.length - 1);
              });
              return KeyEventResult.handled;
            }
            else if (event.logicalKey == LogicalKeyboardKey.arrowRight && _carrito.isNotEmpty) {
              setState(() {
                _enCarrito = true;
                _carritoSeleccionado = 0;
              });
              _rootFocusNode.requestFocus();
              return KeyEventResult.handled;
            }
          } 
          else { 
            // ==========================================
            // ESTAMOS EN EL CARRITO
            // ==========================================
            
            // 🔴 1. SI ESTAMOS EDITANDO UN PRECIO ACTUALMENTE
            if (_indiceEditandoPrecio != -1) {
              if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                // Guardar el precio al presionar Enter
                final newPrice = double.tryParse(_precioController.text);
                setState(() {
                  if (newPrice != null) {
                    _carrito[_indiceEditandoPrecio].precioAplicado = newPrice;
                  }
                  _indiceEditandoPrecio = -1; // Salir de modo edición
                });
                _rootFocusNode.requestFocus(); // Devolver el foco a la caja general
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored; 
            }

            // 🟢 2. MODO NAVEGACIÓN NORMAL (No estamos editando aún)
            if (_carritoSeleccionado < _carrito.length) {
              // Atajos rápidos para EMPEZAR a editar
              String? digit;
              final key = event.logicalKey;
              if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) digit = '0';
              else if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) digit = '1';
              else if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) digit = '2';
              else if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) digit = '3';
              else if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) digit = '4';
              else if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) digit = '5';
              else if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) digit = '6';
              else if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) digit = '7';
              else if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) digit = '8';
              else if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) digit = '9';
              
              if (digit != null) {
                setState(() {
                  _indiceEditandoPrecio = _carritoSeleccionado;
                });
                
                _precioController.value = TextEditingValue(
                  text: digit!,
                  selection: const TextSelection.collapsed(offset: 1),
                );
                
                _precioFocusNode.requestFocus();
                return KeyEventResult.handled;
              }

              // Atajo: E o P abre el editor pero mantiene el precio para modificarlo
              if (key == LogicalKeyboardKey.keyE || key == LogicalKeyboardKey.keyP) {
                setState(() {
                  _indiceEditandoPrecio = _carritoSeleccionado;
                });
                
                String precioTxt = _carrito[_carritoSeleccionado].precioParaVenta.toStringAsFixed(0);
                _precioController.value = TextEditingValue(
                  text: precioTxt,
                  selection: TextSelection.collapsed(offset: precioTxt.length),
                );
                
                _precioFocusNode.requestFocus();
                return KeyEventResult.handled;
              }
            }

            // Moverse por el carrito
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              setState(() { _enCarrito = false; });
              _searchFocusNode.requestFocus();
              return KeyEventResult.handled;
            }
            else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              setState(() {
                _carritoSeleccionado = (_carritoSeleccionado + 1).clamp(0, _carrito.length);
              });
              return KeyEventResult.handled;
            }
            else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              setState(() {
                _carritoSeleccionado = (_carritoSeleccionado - 1).clamp(0, _carrito.length);
              });
              return KeyEventResult.handled;
            }
            else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
              if (_carritoSeleccionado < _carrito.length) {
                _modificarCantidad(_carritoSeleccionado, 1);
              } else if (_carritoSeleccionado == _carrito.length) {
                _abrirPopupCobro();
              }
              return KeyEventResult.handled;
            }
            else if (event.logicalKey == LogicalKeyboardKey.backspace || event.logicalKey == LogicalKeyboardKey.delete) {
              if (_carritoSeleccionado < _carrito.length) {
                _modificarCantidad(_carritoSeleccionado, -1);
              }
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Caja Registradora 💵 (F12 Cobrar)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: Colors.green,
        ),
        body: Row(
          children: [
            // PANEL IZQUIERDO: Buscador
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode, 
                      decoration: InputDecoration(
                        hintText: 'Escanea o busca y presiona Enter (Usa TAB para ir al carrito)...',
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: _enCarrito ? Colors.grey[200] : Colors.white,
                      ),
                      onSubmitted: (_) => _buscarProducto(), 
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _productosBusqueda.length,
                      itemBuilder: (context, index) {
                        final p = _productosBusqueda[index];
                        final isSelected = !_enCarrito && index == _itemBusquedaSeleccionado;
                        
                        return Container(
                          color: isSelected ? Colors.blue.withOpacity(0.15) : Colors.transparent,
                          child: ListTile(
                            leading: Icon(Icons.add_shopping_cart, color: isSelected ? Colors.green : Colors.blue),
                            title: Text(p.nombre, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            subtitle: Text('Stock: ${p.stock} | Precio: \$${p.precioVenta}'),
                            onTap: () {
                              _agregarAlCarrito(p);
                              _searchController.clear();
                              setState(() {
                                _productosBusqueda.clear();
                                _itemBusquedaSeleccionado = -1;
                              });
                              _searchFocusNode.requestFocus(); 
                            }, 
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            
            // PANEL DERECHO: Carrito 
            Expanded(
              flex: 4,
              child: Container(
                color: Colors.grey[100],
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      color: _enCarrito ? Colors.green.withOpacity(0.2) : Colors.transparent,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart, color: _enCarrito ? Colors.green : Colors.black),
                          const SizedBox(width: 10),
                          Text('TICKET DE COMPRA', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _enCarrito ? Colors.green[800] : Colors.black)),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Row(
                        children: const [
                          Expanded(flex: 3, child: Text("PRODUCTO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12))),
                          Expanded(flex: 2, child: Text("PRECIO U.", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12))),
                          Expanded(flex: 2, child: Text("UNIDADES", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12))),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 2),

                    Expanded(
                      child: ListView.builder(
                        itemCount: _carrito.length,
                        itemBuilder: (context, index) {
                          final item = _carrito[index];
                          final isCartSelected = _enCarrito && index == _carritoSeleccionado;
                          final bool isEditing = _indiceEditandoPrecio == index;
                          return Container(
                            color: isCartSelected ? Colors.green.withOpacity(0.15) : Colors.transparent,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Row(
                                children: [
                                  // 1. Nombre 
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      item.producto.nombre, 
                                      style: TextStyle(fontWeight: isCartSelected ? FontWeight.bold : FontWeight.w600, fontSize: 16),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  
                                  // 2. Precio Editable INLINE
                                  Expanded(
                                    flex: 2,
                                    child: isEditing
                                        ? Focus(
                                            onKeyEvent: (node, event) {
                                              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
                                                setState(() { _indiceEditandoPrecio = -1; });
                                                _rootFocusNode.requestFocus();
                                                return KeyEventResult.handled;
                                              }
                                              return KeyEventResult.ignored;
                                            },
                                            child: TextField(
                                              controller: _precioController,
                                              focusNode: _precioFocusNode,
                                              keyboardType: TextInputType.number,
                                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                                prefixText: '\$ ',
                                                border: OutlineInputBorder(),
                                                filled: true,
                                                fillColor: Colors.white,
                                              ),
                                              onSubmitted: (value) {
                                                final newPrice = double.tryParse(value);
                                                setState(() {
                                                  if (newPrice != null) {
                                                    _carrito[index].precioAplicado = newPrice;
                                                  }
                                                  _indiceEditandoPrecio = -1;
                                                });
                                                _rootFocusNode.requestFocus();
                                              },
                                            ),
                                          )
                                        : GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _indiceEditandoPrecio = index;
                                              });
                                              String val = item.precioParaVenta.toStringAsFixed(0);
                                              _precioController.value = TextEditingValue(
                                                text: val,
                                                selection: TextSelection.collapsed(offset: val.length),
                                              );
                                              _precioFocusNode.requestFocus();
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 4),
                                              decoration: BoxDecoration(
                                                border: Border(bottom: BorderSide(color: Colors.grey[400]!, width: 1, style: BorderStyle.solid)),
                                              ),
                                              child: Text(
                                                '\$${item.precioParaVenta.toStringAsFixed(0)}', 
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: item.precioAplicado != null ? Colors.orange[800] : Colors.green[700],
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),

                                  // 3. Controles de cantidad
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 22), 
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _modificarCantidad(index, -1)
                                        ),
                                        const SizedBox(width: 8),
                                        Text('${item.cantidad}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 22), 
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _modificarCantidad(index, 1)
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // BOTÓN DE COBRAR
                    Container(
                      padding: const EdgeInsets.all(20),
                      color: Colors.white,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL:', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                              Text('\$${_totalPagar.toStringAsFixed(0)}', style: const TextStyle(fontSize: 30, color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: Builder(
                              builder: (context) {
                                final bool cobrarSeleccionado = _enCarrito && _carritoSeleccionado == _carrito.length;
                                return ElevatedButton(
                                  onPressed: _carrito.isEmpty ? null : _abrirPopupCobro,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: cobrarSeleccionado ? Colors.lightGreenAccent : Colors.green,
                                    foregroundColor: cobrarSeleccionado ? Colors.black : Colors.white,
                                    side: cobrarSeleccionado ? const BorderSide(color: Colors.black, width: 2) : null,
                                  ),
                                  child: Text(
                                    cobrarSeleccionado ? '¡PRESIONA ENTER PARA COBRAR!' : 'COBRAR (F12)', 
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
                                  ),
                                );
                              }
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}