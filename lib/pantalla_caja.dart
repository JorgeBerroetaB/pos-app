import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/producto.dart';
import 'models/detalle_venta.dart';
import 'services/api_service.dart';
import 'services/ticket_service.dart';
import 'main.dart'; // O el nombre del archivo donde esté tu PantallaInventario

class PantallaCaja extends StatefulWidget {
  const PantallaCaja({super.key});

  @override
  State<PantallaCaja> createState() => _PantallaCajaState();
}

class _PantallaCajaState extends State<PantallaCaja> {
  final ApiService apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  
  // Nodos de enfoque
  final FocusNode _searchFocusNode = FocusNode(); 
  final FocusNode _rootFocusNode = FocusNode(); 
  
  // Edición de precio inline
  final FocusNode _precioFocusNode = FocusNode();
  final TextEditingController _precioController = TextEditingController();
  int _indiceEditandoPrecio = -1; 
  
  List<Producto> _productosBusqueda = []; 
  List<DetalleVenta> _carrito = []; 
  
  int _itemBusquedaSeleccionado = -1;
  bool _enCarrito = false; 
  int _carritoSeleccionado = 0;

  // 🔥 NUEVO ESTADO: Saber si el botón de ir "Atrás" está seleccionado con el teclado
  bool _focoAtras = false;

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
    setState(() => _focoAtras = false); // Quitar foco al botón atrás por si acaso

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

    bool esBalanza = termino.length == 13 && termino.startsWith('20');
    String skuBuscado = termino;
    double? precioBalanza;

    if (esBalanza) {
      String skuExtraido = termino.substring(2, 7);
      skuBuscado = int.parse(skuExtraido).toString(); 
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

  void _agregarAlCarrito(Producto producto, {double? precioBalanza}) {
    setState(() {
      if (precioBalanza != null) {
        final nuevoDetalle = DetalleVenta(producto: producto, cantidad: 1);
        nuevoDetalle.precioAplicado = precioBalanza;
        _carrito.add(nuevoDetalle);
      } else {
        int index = _carrito.indexWhere((item) => item.producto.sku == producto.sku && item.precioAplicado == null);
        if (index != -1) {
          _carrito[index].cantidad++;
        } else {
          _carrito.add(DetalleVenta(producto: producto, cantidad: 1));
        }
      }
      _enCarrito = false;
      _indiceEditandoPrecio = -1; 
      _focoAtras = false;
    });
  }

  void _modificarCantidad(int index, int delta) {
    setState(() {
      _carrito[index].cantidad += delta;
      if (_carrito[index].cantidad <= 0) {
        _carrito.removeAt(index);
        
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

  // =========================================================================
  // 🔥 EL SÚPER POPUP DE COBRO (MULTIPAGO + LISTA DE PAGOS A JAVA) 🔥
  // =========================================================================
  void _abrirPopupCobro() {
    if (_carrito.isEmpty) return;
    setState(() { _indiceEditandoPrecio = -1; }); 

    final double totalActual = _totalPagar;
    final int totalAproximado = _aproximarPesoChileno(totalActual);
    
    bool imprimirTicket = true;
    final TextEditingController tarjetaCtrl = TextEditingController(text: totalAproximado.toString());
    final TextEditingController efectivoCtrl = TextEditingController();
    final TextEditingController transCtrl = TextEditingController();

    final FocusNode switchFocus = FocusNode();
    final FocusNode tarjetaFocus = FocusNode();
    final FocusNode efectivoFocus = FocusNode();
    final FocusNode transFocus = FocusNode();
    final FocusNode popupFocusNode = FocusNode();

    final List<FocusNode> nodosNavegacion = [switchFocus, tarjetaFocus, efectivoFocus, transFocus];
    int focoActualIndex = 1;

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (BuildContext dialogContext) { 
        return StatefulBuilder(
          builder: (BuildContext innerContext, StateSetter setDialogState) {
            
            switchFocus.addListener(() {
              if (switchFocus.hasFocus) setDialogState(() {});
            });

            void cambiarFoco(int index) {
              if (index < 0) index = nodosNavegacion.length - 1;
              if (index >= nodosNavegacion.length) index = 0;
              
              focoActualIndex = index;
              nodosNavegacion[focoActualIndex].requestFocus();
              setDialogState(() {}); 

              if (focoActualIndex == 1) {
                tarjetaCtrl.selection = TextSelection(baseOffset: 0, extentOffset: tarjetaCtrl.text.length);
              } else if (focoActualIndex == 2) {
                efectivoCtrl.selection = TextSelection(baseOffset: 0, extentOffset: efectivoCtrl.text.length);
              } else if (focoActualIndex == 3) {
                transCtrl.selection = TextSelection(baseOffset: 0, extentOffset: transCtrl.text.length);
              }
            }

            if (focoActualIndex == 1 && !tarjetaFocus.hasFocus) {
               Future.delayed(const Duration(milliseconds: 50), () => cambiarFoco(1));
            }

            double pagadoEfec = double.tryParse(efectivoCtrl.text) ?? 0;
            double pagadoTarj = double.tryParse(tarjetaCtrl.text) ?? 0;
            double pagadoTrans = double.tryParse(transCtrl.text) ?? 0;

            double totalPagado = pagadoEfec + pagadoTarj + pagadoTrans;
            double restante = totalAproximado - totalPagado;
            bool pagoCompleto = restante <= 0;
            double vuelto = restante < 0 ? restante.abs() : 0;

            void finalizarVenta() async {
              if (!pagoCompleto) return;

              // --- PREPARAMOS LA LISTA DE PAGOS PARA SPRING BOOT ---
              List<Map<String, dynamic>> listaPagos = [];
              // Si dieron efectivo y hay vuelto, solo enviamos al sistema el efectivo real que entra a la caja
              double efectivoReal = pagadoEfec - vuelto;

              if (pagadoTarj > 0) listaPagos.add({"metodoPago": "TARJETA", "monto": pagadoTarj});
              if (efectivoReal > 0) listaPagos.add({"metodoPago": "EFECTIVO", "monto": efectivoReal});
              if (pagadoTrans > 0) listaPagos.add({"metodoPago": "TRANSFERENCIA", "monto": pagadoTrans});

              try {
                // Enviamos el carrito y la nueva lista de pagos!
                await apiService.registrarVenta(_carrito, listaPagos);
                
                if (!dialogContext.mounted) return; 
                Navigator.pop(dialogContext); 

                if (imprimirTicket) {
                  final ticketService = TicketService();
                  await ticketService.imprimirTicket(
                    carrito: List.from(_carrito), 
                    total: totalActual,
                    totalAproximado: totalAproximado,
                    metodoPago: "MÚLTIPLE", 
                  );
                }

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(imprimirTicket ? '¡Venta registrada e imprimiendo! 💰✅' : '¡Venta registrada sin ticket! 💰✅'), 
                    backgroundColor: Colors.green
                  ),
                );

                setState(() {
                  _carrito.clear();
                  _searchController.clear();
                  _productosBusqueda.clear();
                  _itemBusquedaSeleccionado = -1;
                  _enCarrito = false;
                  _carritoSeleccionado = 0;
                });
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (context.mounted) _searchFocusNode.requestFocus();
                });
              } catch (e) {
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al cobrar: $e'), backgroundColor: Colors.red),
                );
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (context.mounted) _searchFocusNode.requestFocus();
                });
              }
            }

            Widget campoPago(String titulo, TextEditingController ctrl, FocusNode myFocus, int myIndex, IconData icono) {
              return Focus(
                onFocusChange: (hasFocus) {
                  if (hasFocus) focoActualIndex = myIndex; 
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: TextField(
                    controller: ctrl,
                    focusNode: myFocus,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setDialogState(() {}),
                    onSubmitted: (_) {
                      if (pagoCompleto) finalizarVenta();
                    },
                    decoration: InputDecoration(
                      labelText: titulo,
                      prefixIcon: Icon(icono, color: Colors.blueGrey),
                      prefixText: '\$ ',
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: myFocus.hasFocus ? Colors.blue : Colors.grey, 
                          width: myFocus.hasFocus ? 2.0 : 1.0
                        )
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
              );
            }

            return Focus(
              focusNode: popupFocusNode,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    cambiarFoco(focoActualIndex + 1);
                    return KeyEventResult.handled;
                  } 
                  else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    cambiarFoco(focoActualIndex - 1);
                    return KeyEventResult.handled;
                  } 
                  else if (event.logicalKey == LogicalKeyboardKey.escape) {
                    Navigator.pop(dialogContext);
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (context.mounted) _searchFocusNode.requestFocus();
                    });
                    return KeyEventResult.handled;
                  } 
                  else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                    if (focoActualIndex == 0) {
                      setDialogState(() { imprimirTicket = !imprimirTicket; });
                      return KeyEventResult.handled;
                    } else if (pagoCompleto) {
                      finalizarVenta();
                      return KeyEventResult.handled;
                    }
                  } 
                  else if (event.logicalKey == LogicalKeyboardKey.space && focoActualIndex == 0) {
                    setDialogState(() { imprimirTicket = !imprimirTicket; });
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: AlertDialog(
                title: const Text('Finalizar Venta 🧾', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                content: SizedBox(
                  width: 350,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: imprimirTicket ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: switchFocus.hasFocus ? Colors.orange : (imprimirTicket ? Colors.blue : Colors.grey),
                              width: switchFocus.hasFocus ? 3.0 : 1.0, 
                            )
                          ),
                          child: SwitchListTile(
                            focusNode: switchFocus,
                            title: const Text('Imprimir Ticket', style: TextStyle(fontWeight: FontWeight.bold)),
                            value: imprimirTicket,
                            activeColor: Colors.blue,
                            onChanged: (bool value) {
                              setDialogState(() { 
                                imprimirTicket = value;
                                focoActualIndex = 0; 
                                switchFocus.requestFocus();
                              });
                            },
                          ),
                        ),
                        const Divider(height: 30, thickness: 2),

                        const Text('TOTAL A PAGAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Text('\$${totalAproximado.toString()}', style: const TextStyle(fontSize: 45, color: Colors.black, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),

                        campoPago('Tarjeta', tarjetaCtrl, tarjetaFocus, 1, Icons.credit_card),
                        campoPago('Efectivo', efectivoCtrl, efectivoFocus, 2, Icons.payments),
                        campoPago('Transferencia', transCtrl, transFocus, 3, Icons.sync_alt),
                        
                        const SizedBox(height: 15),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: pagoCompleto ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(pagoCompleto ? 'VUELTO:' : 'FALTAN:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: pagoCompleto ? Colors.green[700] : Colors.red[700])),
                              Text(
                                pagoCompleto ? '\$${vuelto.toStringAsFixed(0)}' : '\$${restante.toStringAsFixed(0)}', 
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: pagoCompleto ? Colors.green[700] : Colors.red[700])
                               ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                actions: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          Future.delayed(const Duration(milliseconds: 100), () {
                            if (context.mounted) _searchFocusNode.requestFocus();
                          });
                        },
                        child: const Text('Cancelar (Esc)', style: TextStyle(color: Colors.red, fontSize: 16)),
                      ),
                      ElevatedButton(
                        onPressed: pagoCompleto ? finalizarVenta : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          disabledBackgroundColor: Colors.grey[300],
                        ),
                        child: const Text('Confirmar Venta (Enter)', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  // =========================================================================
  // =========================================================================

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
                _focoAtras = false; // Nos aseguramos de quitarlo
                _searchFocusNode.requestFocus();
              } else {
                if (_carrito.isNotEmpty) {
                  _enCarrito = true;
                  _carritoSeleccionado = 0; 
                  _focoAtras = false;
                  _rootFocusNode.requestFocus();
                }
              }
            });
            return KeyEventResult.handled;
          }

          // 🔥 NUEVO: ESCAPE para salir del foco en "Atrás"
          if (event.logicalKey == LogicalKeyboardKey.escape) {
             if (_focoAtras) {
                 setState(() => _focoAtras = false);
                 _searchFocusNode.requestFocus();
                 return KeyEventResult.handled;
             }
          }

          // 🔥 NUEVO: ENTER sobre el botón Atrás
          if ((event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) && _focoAtras) {
              Navigator.pop(context); // Vuelve al inventario
              return KeyEventResult.handled;
          }

          if (!_enCarrito) {
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              if (_focoAtras) {
                  // Si estamos arriba en "Atrás", bajamos al buscador
                  setState(() => _focoAtras = false);
                  _searchFocusNode.requestFocus();
                  return KeyEventResult.handled;
              } else if (_productosBusqueda.isNotEmpty) {
                  setState(() {
                    _itemBusquedaSeleccionado = (_itemBusquedaSeleccionado + 1).clamp(0, _productosBusqueda.length - 1);
                  });
                  // Movemos foco al root para que el TextField no se coma la flecha
                  if (_searchFocusNode.hasFocus) _rootFocusNode.requestFocus();
                  return KeyEventResult.handled;
              }
            } 
            else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              if (_focoAtras) return KeyEventResult.handled; // Ya estamos arriba

              if (_itemBusquedaSeleccionado > 0) {
                  setState(() {
                    _itemBusquedaSeleccionado = (_itemBusquedaSeleccionado - 1).clamp(0, _productosBusqueda.length - 1);
                  });
                  return KeyEventResult.handled;
              } else if (_itemBusquedaSeleccionado == 0) {
                  setState(() => _itemBusquedaSeleccionado = -1);
                  _searchFocusNode.requestFocus();
                  return KeyEventResult.handled;
              } else if (_itemBusquedaSeleccionado == -1) {
                  // 🔥 ¡LA MAGIA! Subimos del buscador al botón Atrás 🔥
                  setState(() => _focoAtras = true);
                  _searchFocusNode.unfocus();
                  _rootFocusNode.requestFocus();
                  return KeyEventResult.handled;
              }
            }
            else if (event.logicalKey == LogicalKeyboardKey.arrowRight && _carrito.isNotEmpty && !_focoAtras) {
              setState(() {
                _enCarrito = true;
                _carritoSeleccionado = 0;
              });
              _rootFocusNode.requestFocus();
              return KeyEventResult.handled;
            }
            // 🔥 ENTER para agregar producto desde la lista (si lo buscamos con flechas)
            else if ((event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) && _itemBusquedaSeleccionado >= 0) {
                _agregarAlCarrito(_productosBusqueda[_itemBusquedaSeleccionado]);
                return KeyEventResult.handled;
            }
          } 
          else { 
            
            if (_indiceEditandoPrecio != -1) {
              if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                final newPrice = double.tryParse(_precioController.text);
                setState(() {
                  if (newPrice != null) {
                    _carrito[_indiceEditandoPrecio].precioAplicado = newPrice;
                  }
                  _indiceEditandoPrecio = -1; 
                });
                _rootFocusNode.requestFocus(); 
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            }

            if (_carritoSeleccionado < _carrito.length) {
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
                  text: digit,
                  selection: const TextSelection.collapsed(offset: 1),
                );
                _precioFocusNode.requestFocus();
                return KeyEventResult.handled;
              }

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
          // 🔥 MODIFICAMOS EL LEADING (BOTÓN ATRÁS) PARA QUE BRILLE CON _focoAtras 🔥
          leading: Container(
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _focoAtras ? Colors.white.withOpacity(0.4) : Colors.transparent,
              borderRadius: BorderRadius.circular(8)
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              // 🔥 AQUÍ ESTÁ LA MAGIA QUE EVITA LA PANTALLA EN BLANCO 🔥
              onPressed: () => Navigator.pushReplacement(
                context, 
                MaterialPageRoute(builder: (context) => const PantallaInventario())
              ),
            ),
          ),
        ),
        body: Row(
          children: [
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
                      // 🔥 MODIFICADO PARA QUITAR _focoAtras SI TOCAN EL BUSCADOR CON EL MOUSE
                      onTap: () => setState(() {
                        _enCarrito = false;
                        _focoAtras = false; 
                        _itemBusquedaSeleccionado = -1;
                      }),
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
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      item.producto.nombre, 
                                      style: TextStyle(fontWeight: isCartSelected ? FontWeight.bold : FontWeight.w600, fontSize: 16),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  
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