import 'dart:io';

import 'package:desktopapp/components/empleado/inicio.dart';
import 'package:desktopapp/components/empleado/updatearruta.dart';
import 'package:desktopapp/components/provider/ruta_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:provider/provider.dart';
import 'package:desktopapp/components/provider/user_provider.dart';
import 'package:windows_notification/notification_message.dart';
import 'package:windows_notification/windows_notification.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class VentasEmpleado {
  int? costo_entregados;
  final String pendiente;
  final String proceso;
  final String entregado;
  final String truncado;

  VentasEmpleado(
      {this.costo_entregados,
      required this.pendiente,
      required this.proceso,
      required this.entregado,
      required this.truncado});
}

class Vehiculo {
  final int id;
  final String nombre_modelo;
  final String placa;
  final int administrador_id;

  bool seleccionado;
  Vehiculo(
      {required this.id,
      required this.nombre_modelo,
      required this.placa,
      required this.administrador_id,
      this.seleccionado = false});
}

class Empleadopedido {
  int? idruta;
  final int npedido;
  final String estado;
  final String tipo;
  final String fecha;
  double? total;
  final String nombres;
  final String vehiculo;

  Empleadopedido(
      {this.idruta,
      required this.npedido,
      required this.estado,
      required this.tipo,
      required this.fecha,
      required this.total,
      required this.nombres,
      required this.vehiculo});
}

// AGENDADOS
class Pedido {
  final int id;
  int? ruta_id; // Puede ser nulo// Puede ser nulo
  final double subtotal; //
  final double descuento;
  final double total;

  final String fecha;
  final String tipo;
  String estado;
  String? observacion;

  double? latitud;
  double? longitud;
  String? distrito;

  // Atributos adicionales para el caso del GET
  final String nombre; //
  final String apellidos; //
  final String telefono; //

  bool seleccionado; // Nuevo campo para rastrear la selección

  Pedido(
      {required this.id,
      this.ruta_id,
      required this.subtotal,
      required this.descuento,
      required this.total,
      required this.fecha,
      required this.tipo,
      required this.estado,
      this.observacion,
      required this.latitud,
      required this.longitud,
      this.distrito,
      // Atributos adicionales para el caso del GET
      required this.nombre,
      required this.apellidos,
      required this.telefono,
      this.seleccionado = false});
}

// PREGUNTAR SI DEBO MODIFICAR EL MODEL CONDUCTOR AÑADIENDO UN ATRIBUTO
// ESTADO  O EN EL LOGIN PARA VER SI SE CONECTO EN TIEMPO REAL
class Conductor {
  final int id;
  final String nombres;
  final String apellidos;
  final String licencia;
  final String dni;
  final String fecha_nacimiento;

  bool seleccionado; // Nuevo campo para rastrear la selección

  Conductor(
      {required this.id,
      required this.nombres,
      required this.apellidos,
      required this.licencia,
      required this.dni,
      required this.fecha_nacimiento,
      this.seleccionado = false});
}

// CLASE PARA EL MARCADOR
class MarcadorWidget extends StatefulWidget {
  // ATRIBUTOS
  final Color color;

  // CONSTRUCTOR
  MarcadorWidget({required this.color, Key? key}) : super(key: key);

  @override
  _MarcadorWidgetState createState() => _MarcadorWidgetState();
}

class _MarcadorWidgetState extends State<MarcadorWidget> {
  late Color color;

  @override
  void initState() {
    super.initState();
    color = widget.color;
  }

  @override
  Widget build(BuildContext context) {
    /*return Container(
      color: color,
      height: 40,
      width: 40,
    );*/
    return GestureDetector(
      onTap: () {
        setState(() {
          color = Colors.red;
          //  print("s");
        });
      },
      child: Container(
        color: color,
        height: 50,
        width: 50,
      ),
    );
  }
}

// --------------------------------------------------///

class Armado2 extends StatefulWidget {
  const Armado2({super.key});

  @override
  State<Armado2> createState() => _Armado2State();
}

class _Armado2State extends State<Armado2> {
  // CONTROLES DE DESPLAZAMIENTO
  ScrollController _scrollController1 = ScrollController(); //SELECCIONADOS
  ScrollController _scrollController2 = ScrollController(); //HOY
  ScrollController _scrollController3 = ScrollController(); //EXPRESS

  // URI API
  String api = dotenv.env['API_URL'] ?? '';
  String apipedidos = '/api/pedido';
  String conductores = '/api/user_conductor';
  String rutacrear = '/api/ruta';
  String apiRutaCrear = '/api/ruta';
  String apiLastRuta = '/api/rutalast';
  String apiUpdateRuta = '/api/pedidoruta';
  String apiEmpleadoPedidos = '/api/empleadopedido/';
  String apiVehiculos = '/api/vehiculo/';
  String totalventas = '/api/totalventas_empleado/';
  late int rutaIdLast;
  late io.Socket socket;
  late DateTime fechaparseadas;
  DateTime now = DateTime.now();
  List<Pedido> hoypedidos = [];
  List<Pedido> hoyexpress = [];
  List<Pedido> agendados = [];
  ScrollController _scrollControllerExpress = ScrollController();
  late ScrollController _scrollController;

  //LISTAS Y VARIABLES
  List<Pedido> pedidosget = [];
  List<Conductor> conductorget = [];
  List<Pedido> pedidoSeleccionado = [];
  Color sinSeleccionar = Colors.green;
  List<LatLng> seleccionadosUbicaciones = [];
  List<Conductor> obtenerConductor = [];
  List<Vehiculo> obtenerVehiculo = [];
  VentasEmpleado? ventasempleado;
  int conductorid = 0;
  int vehiculoid = 0;

  LatLng currentLcocation = LatLng(0, 0);

  List<LatLng> puntosget = [];
  List<LatLng> puntosnormal = [];
  List<LatLng> puntosexpress = [];

  // EMPLEADOPEDIDOLIST
  List<Empleadopedido> empleadopedido = [];
  List<Vehiculo> vehiculos = [];

  // MARCADORES
  List<Marker> marcadores = [];
  List<Marker> expressmarker = [];
  List<Marker> normalmarker = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  final _winNotifyPlugin = WindowsNotification(
    applicationId:
        r"{D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27}\WindowsPowerShell\v1.0\powershell.exe",
  );
  Map<LatLng, Color> coloreSeleccionados = {};
  int informe = 0;
  String nombre = '';
  String apellidos = '';
  int id = 0;

  void initState() {
    super.initState();
    connectToServer();
    getPedidos();
    getConductores();
    getVehiculos();
    getTotalVentas();

    // marcadoresPut();
  }

  /// MARCA ERROR AQUI.....................................................
  Future<dynamic> getVehiculos() async {
    SharedPreferences empleadoShare = await SharedPreferences.getInstance();
    try {
      // print("...............................URL DE GETVEHICULOS");
      // print(api + apiVehiculos + empleadoShare.getInt('empleadoID').toString());
      var res = await http.get(
          Uri.parse(api +
              apiVehiculos +
              empleadoShare.getInt('empleadoID').toString()),
          headers: {"Content-type": "application/json"});
      //print("........................................RES BODY");
      //print(res.body);
      var data = json.decode(res.body);
      //print("......................data vehiculos x empelado");
      //print(data);
      if (data is List) {
        List<Vehiculo> tempVehiculo = data.map<Vehiculo>((item) {
          return Vehiculo(
            id: item['id'],
            nombre_modelo: item['nombre_modelo'],
            placa: item['placa'],
            administrador_id: item['administrador_id'],
          );
        }).toList();
        setState(() {
          vehiculos = tempVehiculo;
        });
      }
    } catch (e) {
      throw Exception("$e");
    }
  }

  Future<dynamic> getEmpleadoPedido(int empleadoid) async {
    // print("${api}+$apiEmpleadoPedidos+${empleadoid.toString()}");
    var res = await http.get(
        Uri.parse(api + apiEmpleadoPedidos + empleadoid.toString()),
        headers: {"Content-type": "application/json"});
    try {
      var data = json.decode(res.body);
      List<Empleadopedido> tempEmpleadopedido =
          data.map<Empleadopedido>((data) {
        return Empleadopedido(
            idruta: data['idruta'],
            npedido: data['npedido'],
            estado: data['estado'],
            tipo: data['tipo'],
            fecha: data['fecha'],
            total: data['total']?.toDouble() ?? 0.0,
            nombres: data['nombres'],
            vehiculo: data['vehiculo']);
      }).toList();
      setState(() {
        empleadopedido = tempEmpleadopedido;
        //  print("$tempEmpleadopedido");
      });
    } catch (e) {
      throw Exception('$e');
    }
  }

  Future<String> getImageBytes(String assetPath) async {
    final supportDir = await getApplicationSupportDirectory();
    final bytes = await rootBundle.load(assetPath);
    final imageFile =
        File("${supportDir.path}/${DateTime.now().millisecond}.png");
    await imageFile.create();
    await imageFile.writeAsBytes(bytes.buffer.asUint8List());
    return imageFile.path;
  }

  Future<dynamic> refresh() async {
    setState(() {});
  }

  Future<dynamic> getConductores() async {
    try {
      SharedPreferences empleadoShare = await SharedPreferences.getInstance();
      var empleadoIDs = empleadoShare.getInt('empleadoID');
      print("El empleado traido es");
      print(empleadoIDs);
      var res = await http.get(
          Uri.parse(api + conductores + '/' + empleadoIDs.toString()),
          headers: {"Content-type": "application/json"});

      if (res.statusCode == 200) {
        var data = json.decode(res.body);
        List<Conductor> tempConductor = data.map<Conductor>((data) {
          return Conductor(
              id: data['id'],
              nombres: data['nombres'],
              apellidos: data['apellidos'],
              licencia: data['licencia'],
              dni: data['dni'],
              fecha_nacimiento: data['fecha_nacimiento']);
        }).toList();
        setState(() {
          conductorget = tempConductor;
        });
      }
    } catch (e) {
      throw Exception('$e');
    }
  }

  // POST RUTA
  /// AQUI AGREGO EL CARRITO PUNNNNN
  Future<dynamic> createRuta(
      empleado_id, conductor_id, vehiculo_id, distancia, tiempo) async {
    try {
      //    print("Create ruta....");
      //print("conductor ID");
      //print(conductor_id);
      //print("vehiculo_id");
      //print(vehiculo_id);

      DateTime horaactual = DateTime.now();
      String formateDateTime =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(horaactual);
      await http.post(Uri.parse(api + apiRutaCrear),
          headers: {"Content-type": "application/json"},
          body: jsonEncode({
            "conductor_id": conductor_id,
            "vehiculo_id": vehiculo_id,
            "empleado_id": empleado_id,
            "distancia_km": distancia,
            "tiempo_ruta": tiempo,
            "fecha_creacion": formateDateTime
          }));
      // print("Ruta creada");
    } catch (e) {
      throw Exception("$e");
    }
  }

  // LAST RUTA BY EMPRLEADOID
  Future<dynamic> lastRutaEmpleado(empleadoId) async {
    var res = await http.get(
        Uri.parse(api + apiLastRuta + '/' + empleadoId.toString()),
        headers: {"Content-type": "application/json"});

    setState(() {
      rutaIdLast = json.decode(res.body)['id'] ?? 0;
    });
    //print("LAST RUTA EMPLEAD");
    //print(rutaIdLast);
  }

  // UPDATE PEDIDO-RUTA
  Future<dynamic> updatePedidoRuta(ruta_id, estado) async {
    for (var i = 0; i < pedidoSeleccionado.length; i++) {
      await http.put(
          Uri.parse(
              api + apiUpdateRuta + '/' + pedidoSeleccionado[i].id.toString()),
          headers: {"Content-type": "application/json"},
          body: jsonEncode({"ruta_id": ruta_id, "estado": estado}));
    }
    // print("RUTA ACTUALIZADA A ");
    // print(ruta_id);

    //ALMACENO LA RUTA EN EL PROVIDER PARA ESE CONDUCTOR
    Provider.of<RutaProvider>(context, listen: false).updateUser(ruta_id);
  }

  // CREAR Y OBTENER
  Future<void> crearobtenerYactualizarRuta(
      empleadoId, conductorid, vehiculoid, distancia, tiempo, estado) async {
    await createRuta(empleadoId, conductorid, vehiculoid, distancia, tiempo);
    await lastRutaEmpleado(empleadoId);
    await updatePedidoRuta(rutaIdLast, estado);
    socket.emit('Termine de Updatear', 'si');
  }

  void getUbicacionSeleccionada() {
    // print("ubicaciones seleccionadas");
    // print(seleccionadosUbicaciones);
  }

// Función para comparar coordenadas con tolerancia
  bool _isCoordenadaIgual(double valor1, double valor2) {
    //print("VALOR 1");
    //print(valor1);
    //print("VALOR 2");
    //print(valor2);
    const tolerancia =
        0.0000000001; // Puedes ajustar la tolerancia según tus necesidades
    return (valor1 - valor2).abs() < tolerancia;
  }

  // FUNCIONES
  void marcadoresPut(tipo) {
    if (tipo == 'agendados') {
      int count = 1;

      final Map<LatLng, Pedido> mapaLatPedido = {};

      for (var i = 0; i < puntosget.length; i++) {
        //print("---||||||||||||||||||||---");
        //print(puntosget[i].latitude);
        //print(puntosget[i].longitude);
        double offset = count * 0.000001;
        LatLng coordenada = puntosget[i];
        Pedido pedido = agendados[i];

        mapaLatPedido[LatLng(coordenada.latitude, coordenada.longitude)] =
            pedido;

        setState(() {
          marcadores.add(
            Marker(
              point: LatLng(
                  coordenada.latitude + offset, coordenada.longitude + offset),
              width: 140,
              height: 150,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    mapaLatPedido[
                            LatLng(coordenada.latitude, coordenada.longitude)]
                        ?.estado = 'en proceso';
                    Pedido? pedidoencontrado = mapaLatPedido[
                        LatLng(coordenada.latitude, coordenada.longitude)];
                    pedidoSeleccionado.add(pedidoencontrado!);
                  });
                },
                child: Container(
                    height: 155,
                    width: 140,
                    //color: Colors.grey,
                    child: Column(
                      children: [
                        Container(
                          height: 50,
                          width: 50,
                          padding: const EdgeInsets.all(0),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(50),
                              color: Colors.white.withOpacity(0.5),
                              border: Border.all(
                                  width: 1,
                                  color:
                                      const Color.fromARGB(255, 12, 112, 16))),
                          child: Center(
                              child: Text(
                            "${count}",
                            style: const TextStyle(
                                fontSize: 19,
                                color: Colors.black,
                                fontWeight: FontWeight.w600),
                          )),
                        ),
                        Container(
                          //margin: const EdgeInsets.only(right: 20),
                          width: 94,
                          height: 94,
                          // color:Colors.blueGrey,
                          decoration: BoxDecoration(
                              // color: Colors.black,
                              borderRadius: BorderRadius.circular(20),
                              image: const DecorationImage(
                                  image: AssetImage(
                                      'lib/imagenes/greenfinal.png'))),
                        ),
                      ],
                    ) /*Icon(Icons.location_on_outlined,
              size: 40,color: Colors.blueAccent,)*/
                    ),
              ),
            ),
          );
        });
        count++;
      }
    }
  }

  Future<dynamic> getPedidos() async {
    try {
      print("---------dentro ..........................get pdeidos");
      print(apipedidos);
      SharedPreferences empleadoShare = await SharedPreferences.getInstance();

      var empleadoIDs = empleadoShare.getInt('empleadoID');
      var res = await http.get(
          Uri.parse(api + apipedidos + '/' + empleadoIDs.toString()),
          headers: {"Content-type": "application/json"});
      if (res.statusCode == 200) {
        var data = json.decode(res.body);
        List<Pedido> tempPedido = data.map<Pedido>((data) {
          return Pedido(
              id: data['id'],
              ruta_id: data['ruta_id'] ?? 0,
              subtotal: data['subtotal']?.toDouble() ?? 0.0,
              descuento: data['descuento']?.toDouble() ?? 0.0,
              total: data['total']?.toDouble() ?? 0.0,
              fecha: data['fecha'],
              tipo: data['tipo'],
              estado: data['estado'],
              latitud: data['latitud']?.toDouble() ?? 0.0,
              longitud: data['longitud']?.toDouble() ?? 0.0,
              nombre: data['nombre'] ?? '',
              apellidos: data['apellidos'] ?? '',
              telefono: data['telefono'] ?? '');
        }).toList();

        setState(() {
          pedidosget = tempPedido;

          int count = 1;
          for (var i = 0; i < pedidosget.length; i++) {
            fechaparseadas = DateTime.parse(pedidosget[i].fecha.toString());
            if (pedidosget[i].estado == 'pendiente') {
              // print("pendi...");
              if (pedidosget[i].tipo == 'normal') {
                // print("normlllll");
                // SI ES NORMAL
                if (fechaparseadas.day != now.day) {
                  // print("no es hoy");
                  // print(fechaparseadas.day);

                  setState(() {
                    LatLng coordGET = LatLng(
                        (pedidosget[i].latitud ?? 0.0) + (0.000001 * count),
                        (pedidosget[i].longitud ?? 0.0) + (0.000001 * count));

                    puntosget.add(coordGET);
                    pedidosget[i].latitud = coordGET.latitude;
                    pedidosget[i].longitud = coordGET.longitude;

                    // print("--get posss");
                    // print(coordGET);
                    agendados.add(pedidosget[i]);
                  });
                }
              } else if (pedidosget[i].tipo == 'express') {
                hoyexpress.add(pedidosget[i]);
              }
            } else {
              setState(() {});
            }
            count++;
          }
        });

        // OBTENER COORDENADAS DE LOS PEDIDOS
        // for (var i = 0; i < pedidosget.length; i++) {}
        //print("PUNTOS GET");
        //print(puntosget);

        // PONER MARCADOR PARA AGENDADOS
        marcadoresPut("agendados");
        setState(() {});
      }
    } catch (e) {
      throw Exception('Error $e');
    }
  }

  Future<File> saveDocument(
      {required String name, required pw.Document pdf}) async {
    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');

    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> openDocument(File file) async {
    await OpenFile.open(file.path);
  }

  Future<File> createPdf() async {
    // NÚMERO DE INFORME
    informe++;

    final pdf = pw.Document();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin:
          const pw.EdgeInsets.only(top: 20, bottom: 20, left: 20, right: 20),
      build: (context) => [
        pw.Column(children: [
          pw.Center(
              child: pw.Container(
                  height: 30,
                  decoration: pw.BoxDecoration(
                      borderRadius: pw.BorderRadius.circular(20),
                      color: PdfColor.fromInt(Colors.amber.value)),
                  child: pw.Center(
                      child: pw.Text("Informe N° ${informe}".toUpperCase(),
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 15,
                              color: PdfColor.fromInt(
                                  const Color.fromARGB(255, 12, 39, 62)
                                      .value)))))),
        ]),

        // ESPACIO
        pw.SizedBox(height: 30),

        pw.Container(
            width: 200,
            height: 80,
            padding: pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(10),
                color: PdfColor.fromInt(Colors.blue.value)),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("ID: ${id}",
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(Colors.white.value))),
                  pw.Text("Nombres: ${nombre}",
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(Colors.white.value))),
                  pw.Text("Apellidos: ${apellidos}",
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(Colors.white.value))),
                  pw.Text("Fecha: ${now.day}/${now.month}/${now.year}",
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(Colors.white.value))),
                ])),
        pw.Container(
            width: 250,
            height: 120,
            padding: pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(20),
                color: PdfColor.fromInt(Colors.teal.value)),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                      "MONTO ENTREGADOS: S/.${ventasempleado?.costo_entregados}.00",
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(Colors.purple.value))),
                  pw.Text("ESTADO DE PEDIDOS",
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(Colors.white.value))),
                  pw.Text("Pendiente: ${ventasempleado?.pendiente}",
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(Colors.white.value))),
                  pw.Text("Proceso: ${ventasempleado?.proceso}",
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(Colors.white.value))),
                  pw.Text("Entregado: ${ventasempleado?.entregado}",
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(Colors.white.value))),
                  pw.Text("Truncado: ${ventasempleado?.truncado}",
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(Colors.white.value))),
                ])),
        //ESPACIO
        pw.SizedBox(height: 30),

        //TABLA
        /* pw.Table(border: pw.TableBorder.all(), children: [
          pw.TableRow(children: [
            pw.Text("Cantidad de Pedido".toUpperCase()),
            pw.Text("Monto".toUpperCase()),
            pw.Text("Unidad Móvil".toUpperCase()),
          ]),
          for (var i = 0; i < pedidosget.length; i++)
            pw.TableRow(children: [
              pw.Text("Pedido n° ${pedidosget[i].id}".toUpperCase()),
              pw.Text("Estado: ${pedidosget[i].estado}".toUpperCase()),
              pw.Text("Unidad Móvil".toUpperCase()),
            ]),
          pw.TableRow(children: [
            pw.Container(
                height: 20,
                width: 20,
                child: pw.ListView.builder(
                    itemCount: 10,
                    itemBuilder: (context, index) {
                      return pw.Column(children: [pw.Text("asd")]);
                    })),
          ])
        ])*/
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            pw.TableRow(
              children: [
                pw.Text("N° Registro", style: pw.TextStyle(fontSize: 12)),
                pw.Text("Ruta N°"),
                pw.Text("Pedido N°"),
                pw.Text("Fecha"),
                pw.Text("Tipo de Pedido".toUpperCase()),
                pw.Text("Estado del Pedido".toUpperCase()),
                pw.Text("Monto total".toUpperCase()),
                pw.Text("Conductor".toUpperCase()),
                pw.Text("Unidad Móvil".toUpperCase())
              ],
            ),
            for (var i = 0; i < empleadopedido.length; i++)
              pw.TableRow(
                children: [
                  pw.Text("${i + 1}"), //n registro
                  pw.Text("${empleadopedido[i].idruta}"), //id ruta
                  pw.Text("${empleadopedido[i].npedido}"),
                  pw.Text("${empleadopedido[i].fecha}"),
                  pw.Text("${empleadopedido[i].tipo}"), //tipo
                  pw.Text("${empleadopedido[i].estado}".toUpperCase()), //estado
                  pw.Text("S/.${empleadopedido[i].total}"), //monto total
                  pw.Text("${empleadopedido[i].nombres}"),
                  pw.Text("${empleadopedido[i].vehiculo}")
                ],
              ),
          ],
        ),
      ],
    ));

    final savedFile = await saveDocument(
        name: 'informe_${now.day}-${now.month}-${now.year}', pdf: pdf);
    await openDocument(savedFile);

    return savedFile;
    /*return saveDocument(
      name:'informe${1}',pdf:pdf
    );*/
  }

  void connectToServer() {
    //print("-----CONEXIÓN------");

    socket = io.io(api, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnect': true,
      'reconnectionAttempts': 5,
      'reconnectionDelay': 1000,
    });

    socket.connect();

    socket.onConnect((_) {
      //print('Conexión establecida: EMPLEADO');
    });

    socket.onDisconnect((_) {
      //print('Conexión desconectada: EMPLEADO');
    });

    socket.on('nuevoPedido', (data) {
      if (data['tipo'] == 'express') {
        // _showNotification(data['tipo']);
      } else {
        //  _showNotification(data['tipo']);
      }
    });

    socket.onConnectError((error) {
      //print("error de conexion $error");
    });

    socket.onError((error) {
      print("error de socket, $error");
    });

    socket.on('testy', (data) {
      //print("CARRRR");
    });

    socket.on('enviandoCoordenadas', (data) {
      // print("Conductor transmite:");
      // print(data);
      setState(() {
        currentLcocation = LatLng(data['x'], data['y']);
      });
    });

    socket.on('vista', (data) {
      // print("...recibiendo..");
      // //getPedidos();
      // print(data);
    });
  }

  void _showNotification(String tipo) async {
    if (tipo == 'express') {
      String imagePath = await getImageBytes('lib/imagenes/amberfinal.png');
      NotificationMessage message = NotificationMessage.fromPluginTemplate(
        "Pedido",
        "Llegó un pedido!",
        "$tipo",
        largeImage: imagePath,
      );
      _winNotifyPlugin.showNotificationPluginTemplate(message);

      // Ejecutar en el hilo principal de Flutter
      MethodChannel('tu_canal').invokeMethod('mostrarNotificacion', {
        'title': message.title,
        'body': message.body,
        'largeImage': message.largeImage,
      });
    } else {
      String imagePath = await getImageBytes('lib/imagenes/bluefinal.png');
      NotificationMessage message = NotificationMessage.fromPluginTemplate(
        "Pedido",
        "Llegó un pedido!",
        "$tipo",
        largeImage: imagePath,
      );
      _winNotifyPlugin.showNotificationPluginTemplate(message);
    }
  }

  Future<void> getTotalVentas() async {
    SharedPreferences empleadoShare = await SharedPreferences.getInstance();

    var res = await http.get(
      Uri.parse(
          api + totalventas + empleadoShare.getInt('empleadoID').toString()),
      headers: {"Content-type": "application/json"},
    );

    try {
      var data = json.decode(res.body);

      // Crear una instancia de VentasEmpleado directamente desde el objeto JSON
      VentasEmpleado ventasEmpleado = VentasEmpleado(
        costo_entregados: data['costo_entregados'] ?? 0,
        pendiente: data['pendiente'] ?? "",
        proceso: data['proceso'] ?? "",
        entregado: data['entregados'] ?? "",
        truncado: data['truncados'] ?? "",
      );

      setState(() {
        ventasempleado = ventasEmpleado;
      });
    } catch (e) {
      throw Exception("$e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    nombre = userProvider.user!.nombre;
    apellidos = userProvider.user!.apellidos;
    id = userProvider.user!.id;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Stack(
            children: [
              FlutterMap(
                options: const MapOptions(
                  initialCenter: LatLng(-16.4055657, -71.5719081),
                  initialZoom: 13.2,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(
                    markers: [
                      ...marcadores,
                      //...expressmarker,
                      // ...normalmarker,
                    ],
                  ),
                ],
              ),

              // VEHICULOS
              Positioned(
                top: MediaQuery.of(context).size.height / 7,
                left: 10,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    // color: Colors.amber
                  ),
                  margin: const EdgeInsets.only(left: 10),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.teal,
                        ),
                        child: Text(
                          "Vehículos: ${vehiculos.length}",
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        height: 200,
                        width: 400,
                        child: ListView.builder(
                          itemCount: vehiculos.length,
                          itemBuilder: (context, index) {
                            return Container(
                                padding: const EdgeInsets.all(0),
                                margin: const EdgeInsets.only(top: 15),
                                decoration: BoxDecoration(
                                    color: Colors.teal.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(20)),
                                child: ListTile(
                                    trailing: Checkbox(
                                      checkColor: const Color.fromARGB(
                                          255, 209, 154, 154),
                                      value: vehiculos[index]
                                          .seleccionado, //conductorget[index].seleccionado,
                                      onChanged: (value) {
                                        setState(() {
                                          vehiculos[index].seleccionado =
                                              value ?? false;
                                          obtenerVehiculo = vehiculos
                                              .where((element) =>
                                                  element.seleccionado)
                                              .toList();
                                          if (value == true) {
                                            setState(() {
                                              vehiculoid = vehiculos[index].id;
                                            });
                                            // print("---%%%% vehiculo id");
                                            // print(vehiculoid);
                                          }
                                        });
                                      },
                                    ),
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "ID: ${vehiculos[index].id}",
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          "Nombre: ${vehiculos[index].nombre_modelo}",
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          "Placa: ${vehiculos[index].placa}",
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        )
                                      ],
                                    )));
                          },
                        ),
                      )
                    ],
                  ),
                ),
              ),

              // AGENDADOS
              Positioned(
                bottom: 30,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.all(15),
                  width: 250,
                  height: MediaQuery.of(context).size.height / 2,
                  decoration: BoxDecoration(
                      //  color: Colors.white.withOpacity(0.7),
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      /*Text(
                        "${MediaQuery.of(context).size.width} x ${MediaQuery.of(context).size.height}",
                        style: TextStyle(
                            color: Colors.purple, fontWeight: FontWeight.bold),
                      ),*/
                      Text(
                        "Agendados: ${agendados.length}",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: const Color.fromARGB(255, 6, 53, 91)),
                      ),
                      Container(
                        width: 300,
                        height: MediaQuery.of(context).size.height / 2.5,
                        color: Colors.grey,
                        child: ListView.builder(
                            key: _listKey,
                            itemCount: agendados.length,
                            itemBuilder: ((context, index) {
                              return Container(
                                margin: const EdgeInsets.only(top: 10),
                                padding: const EdgeInsets.all(6),
                                height: 180,
                                decoration: BoxDecoration(
                                    color:
                                        agendados[index].estado == 'pendiente'
                                            ? Color.fromARGB(255, 58, 108, 149)
                                            : Color.fromARGB(255, 12, 46, 14)
                                                .withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Pedido : N° ${agendados[index].id}",
                                        style: TextStyle(
                                            fontSize: 15,
                                            color: Colors.white,
                                            fontWeight: FontWeight.normal)),
                                    Text("Cliente: ${agendados[index].nombre}",
                                        style: TextStyle(
                                            fontSize: 15,
                                            color: Colors.white,
                                            fontWeight: FontWeight.normal)),
                                    Text(
                                        "Telefono:${agendados[index].telefono}",
                                        style: TextStyle(
                                            fontSize: 15,
                                            color: Colors.white,
                                            fontWeight: FontWeight.normal)),
                                    Text("Monto: S/.${agendados[index].total}",
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.white,
                                        )),
                                    Text("Fecha: ${agendados[index].fecha}",
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.white,
                                        )),
                                    Text(
                                      "Estado: ${agendados[index].estado}",
                                      style: TextStyle(
                                          fontSize: 15,
                                          color: agendados[index].estado ==
                                                  'pendiente'
                                              ? Color.fromARGB(
                                                  255, 186, 115, 135)
                                              : agendados[index].estado ==
                                                      'en proceso'
                                                  ? Colors.amber
                                                  : Colors.black,
                                          fontWeight: FontWeight.w700),
                                    )
                                  ],
                                ),
                              );
                            })),
                      ),
                    ],
                  ),
                ),
              ),

              // SISTEMA DE PEDIDO
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  // color: Colors.grey,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const Inicio()));
                    },
                    style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all(
                            const Color.fromARGB(255, 58, 108, 149)
                                .withOpacity(0.8))),
                    child: const Text(
                      "<< Sistema de Pedido",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),

              // SISTEMA DE SUPERVISIÓN
              Positioned(
                top: 10,
                left: 210,
                child: Container(
                  height: 50,
                  //color: Colors.grey,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const Update()));
                    },
                    style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all(
                            const Color.fromARGB(255, 58, 108, 149)
                                .withOpacity(0.8))),
                    child: const Text(
                      "Sistema de Supervisión >>",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),

              /*
              // HOY
              Positioned(
                left: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    //color: Colors.white
                  ),
                  // color: Color.fromARGB(255, 221, 214, 214),
                  //height: 180,
                  width: MediaQuery.of(context).size.width / 2.05,
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Color.fromARGB(255, 2, 51, 92)
                                    .withOpacity(0.8)),
                            child: Text(
                              "Hoy: ${hoypedidos.length}",
                              style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            )),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragUpdate: (details) {
                          _scrollController3.jumpTo(
                              _scrollController3.position.pixels +
                                  details.primaryDelta!);
                        },
                        child: SingleChildScrollView(
                          controller: _scrollController3,
                          scrollDirection: Axis.horizontal,
                          reverse: false,
                          child: Row(
                            children: List.generate(
                              hoypedidos.length,
                              (index) => Container(
                                margin: const EdgeInsets.only(left: 10),
                                padding: const EdgeInsets.all(8),
                                //color: Colors.purple,
                                child: Card(
                                  elevation: 8,
                                  borderOnForeground: true,
                                  color: hoypedidos[index].estado == 'pendiente'
                                      ? Color.fromARGB(255, 1, 44, 79)
                                          .withOpacity(0.75)
                                      : const Color.fromARGB(255, 15, 59, 16)
                                          .withOpacity(0.75),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Pedido : N° ${hoypedidos[index].id}",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white),
                                        ),
                                        Text(
                                          "Ruta N°:${hoypedidos[index].ruta_id}",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          "Cliente:${hoypedidos[index].nombre}",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        Text(
                                          "Telefono:${hoypedidos[index].telefono}",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        Text(
                                          "Monto: S/.${hoypedidos[index].total}",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        Text(
                                          "Fecha: ${hoypedidos[index].fecha}",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        Text(
                                            "Estado: ${hoypedidos[index].estado}",
                                            style: TextStyle(
                                              color: hoypedidos[index].estado ==
                                                      'pendiente'
                                                  ? Colors.white
                                                  : hoypedidos[index].estado ==
                                                          'en proceso'
                                                      ? Colors.amber
                                                      : Colors.black,
                                              fontWeight: FontWeight.bold,
                                            )),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // EXPRESS
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    //color: Colors.white
                  ),
                  // color: Color.fromARGB(255, 221, 214, 214),
                  // height: 180,
                  width: MediaQuery.of(context).size.width / 2.05,
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              "Express: ${hoyexpress.length}",
                              style: TextStyle(
                                  fontSize: 20,
                                  color: Color.fromARGB(255, 254, 254, 254),
                                  fontWeight: FontWeight.w500),
                            )),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragUpdate: (details) {
                          _scrollController2.jumpTo(
                              _scrollController2.position.pixels +
                                  details.primaryDelta!);
                        },
                        child: SingleChildScrollView(
                          controller: _scrollController2,
                          scrollDirection: Axis.horizontal,
                          reverse: false,
                          child: Row(
                            children: List.generate(
                              hoyexpress.length,
                              (index) => Container(
                                margin: const EdgeInsets.only(left: 10),
                                padding: const EdgeInsets.all(8),
                                child: Card(
                                  elevation: 8,
                                  borderOnForeground: true,
                                  color: hoyexpress[index].estado == 'pendiente'
                                      ? Color.fromARGB(255, 246, 188, 15)
                                          .withOpacity(0.7)
                                      : Color.fromARGB(255, 18, 84, 20)
                                          .withOpacity(0.7),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Pedido : N° ${hoyexpress[index].id}",
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          "Ruta N°:${hoyexpress[index].ruta_id}",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                            "Cliente:${hoyexpress[index].nombre}",
                                            style: TextStyle(
                                              color: Colors.white,
                                            )),
                                        Text(
                                            "Telefono:${hoyexpress[index].telefono}",
                                            style: TextStyle(
                                              color: Colors.white,
                                            )),
                                        Text(
                                            "Monto: S/.${hoyexpress[index].total}",
                                            style: TextStyle(
                                              color: Colors.white,
                                            )),
                                        Text(
                                            "Fecha: ${hoyexpress[index].fecha}",
                                            style: TextStyle(
                                              color: Colors.white,
                                            )),
                                        Text(
                                          "Estado: ${hoyexpress[index].estado}",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

                */

              // CONDUCTORES
              Positioned(
                top: MediaQuery.of(context).size.height / 8,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  width: 190,
                  height: MediaQuery.of(context).size.height / 1.2,
                  decoration: BoxDecoration(
                      //color: Colors.white,
                      borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      Text(
                        "Conductores: ${conductorget.length}",
                        style: TextStyle(
                            fontSize: 20,
                            color: Color.fromARGB(255, 30, 63, 91),
                            fontWeight: FontWeight.w500),
                      ),
                      Container(
                        width: 195,
                        height: 500,
                        child: ListView.builder(
                            itemCount: conductorget.length,
                            itemBuilder: ((context, index) {
                              return Container(
                                  margin: const EdgeInsets.only(top: 10),
                                  height: 100,
                                  decoration: BoxDecoration(
                                      color: Color.fromARGB(255, 58, 108, 149)
                                          .withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(20)),
                                  child: ListTile(
                                    trailing: Checkbox(
                                      checkColor: Colors.white,
                                      value: conductorget[index].seleccionado,
                                      onChanged: (value) {
                                        setState(() {
                                          conductorget[index].seleccionado =
                                              value ?? false;
                                          obtenerConductor = conductorget
                                              .where((element) =>
                                                  element.seleccionado)
                                              .toList();
                                          if (value == true) {
                                            setState(() {
                                              conductorid =
                                                  conductorget[index].id;
                                            });
                                            //print("conductor id ");
                                            //print(conductorid);
                                          }
                                        });
                                      },
                                    ),
                                    title: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Conductor : N° ${conductorget[index].id}",
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.white,
                                              fontWeight: FontWeight.normal),
                                        ),
                                        Text(
                                          "Nombre: ${conductorget[index].nombres}",
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white,
                                              fontWeight: FontWeight.normal),
                                        ),
                                      ],
                                    ),
                                  ) /*,*/
                                  );
                            })),
                      ),
                    ],
                  ),
                ),
              ),

              // SELECCIONADOS
              Positioned(
                left: (MediaQuery.of(context).size.width - 500) / 2,
                height: 150,
                width: 500,
                child: Container(
                  padding: const EdgeInsets.all(5),

                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white),
                  // color: Color.fromARGB(255, 221, 214, 214),

                  child: Column(
                    children: [
                      Center(
                        child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              "Seleccionados: ${pedidoSeleccionado.length}",
                              style: TextStyle(
                                  fontSize: 15,
                                  color: Color.fromARGB(255, 255, 255, 255),
                                  fontWeight: FontWeight.w500),
                            )),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragUpdate: (details) {
                          _scrollController1.jumpTo(
                              _scrollController1.position.pixels +
                                  details.primaryDelta!);
                        },
                        child: SingleChildScrollView(
                          controller: _scrollController1,
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          child: Row(
                            children: List.generate(
                              pedidoSeleccionado.length,
                              (index) => Container(
                                margin: const EdgeInsets.only(left: 10),
                                padding: const EdgeInsets.all(2),
                                //color: Colors.purple,
                                child: Card(
                                  elevation: 8,
                                  borderOnForeground: true,
                                  color: const Color.fromARGB(255, 58, 108, 149)
                                      .withOpacity(0.8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Pedido : N° ${pedidoSeleccionado[index].id}",
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w300),
                                        ),
                                        Text(
                                            "Ruta: ${pedidoSeleccionado[index].ruta_id}",
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w300))
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      ElevatedButton(
                          onPressed: () {
                            setState(() {
                              for (var i = 0;
                                  i < pedidoSeleccionado.length;
                                  i++) {
                                pedidoSeleccionado[i].estado = 'pendiente';
                              }
                              pedidoSeleccionado = [];
                            });
                          },
                          style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all(
                                  Color.fromARGB(255, 58, 108, 149)
                                      .withOpacity(0.8))),
                          child: Text(
                            "Deshacer",
                            style: TextStyle(color: Colors.white),
                          ))
                    ],
                  ),
                ),
              ),

              // INFORME
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  height: 100,
                  width: 100,
                  decoration:
                      BoxDecoration(borderRadius: BorderRadius.circular(100)),
                  child: ElevatedButton(
                    onPressed: () async {
                      await getEmpleadoPedido(userProvider.user!.id);
                      await createPdf();
                    },
                    child: Text(
                      "Informe",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all(
                            Colors.amber.withOpacity(0.8))),
                  ),
                ),
              ),
              // CREAR
              Positioned(
                right: 110,
                top: 10,
                child: Container(
                  height: 100,
                  width: 100,
                  decoration:
                      BoxDecoration(borderRadius: BorderRadius.circular(100)),
                  child: ElevatedButton(
                    onPressed: (pedidoSeleccionado.isNotEmpty &&
                            obtenerConductor.isNotEmpty &&
                            obtenerVehiculo.isNotEmpty)
                        ? () async {
                            showDialog<String>(
                              context: context,
                              builder: (BuildContext context) => AlertDialog(
                                title:
                                    Center(child: const Text('¿ Crear ruta ?')),
                                actions: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // CANCELAR
                                      ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            for (var i = 0;
                                                i < pedidoSeleccionado.length;
                                                i++) {
                                              pedidoSeleccionado[i].estado =
                                                  'pendiente';
                                            }
                                            for (var i = 0;
                                                i < obtenerConductor.length;
                                                i++) {
                                              obtenerConductor[i].seleccionado =
                                                  false;
                                            }
                                            for (var i = 0;
                                                i < obtenerVehiculo.length;
                                                i++) {
                                              obtenerVehiculo[i].seleccionado =
                                                  false;
                                            }
                                            pedidoSeleccionado = [];
                                            obtenerConductor = [];
                                            obtenerVehiculo = [];
                                          });
                                          Navigator.pop(context, 'CANCELAR');
                                        },
                                        style: ButtonStyle(
                                            backgroundColor:
                                                MaterialStateProperty.all(
                                                    Colors.amber)),
                                        child: const Text(
                                          'Cancelar',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),

                                      // CONFIRMAR
                                      ElevatedButton(
                                        onPressed: () async {
                                          // Muestra el indicador de progreso
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (BuildContext context) {
                                              return Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              );
                                            },
                                          );

                                          //   print(obtenerConductor);
                                          await crearobtenerYactualizarRuta(
                                            userProvider.user?.id,
                                            conductorid,
                                            vehiculoid,
                                            0,
                                            0,
                                            "en proceso",
                                          );

                                          for (var i = 0;
                                              i < obtenerConductor.length;
                                              i++) {
                                            setState(() {
                                              obtenerConductor[i].seleccionado =
                                                  false;
                                            });
                                          }
                                          for (var i = 0;
                                              i < obtenerVehiculo.length;
                                              i++) {
                                            setState(() {
                                              obtenerVehiculo[i].seleccionado =
                                                  false;
                                            });
                                          }

                                          // Limpiar y ocultar el indicador de progreso
                                          Navigator.pop(context);
                                          setState(() {
                                            pedidoSeleccionado = [];
                                            obtenerConductor = [];
                                          });

                                          // Actualizar la interfaz de usuario
                                          _listKey.currentState
                                              ?.setState(() {});

                                          Navigator.pop(context);
                                          setState(() {
                                            // getPedidos();
                                          });
                                        },
                                        style: ButtonStyle(
                                            backgroundColor:
                                                MaterialStateProperty.all(
                                                    Color.fromARGB(
                                                        255, 58, 108, 149))),
                                        child: const Text(
                                          'Crear',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            );
                          }
                        : null,
                    child: Text(
                      "Crear",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(
                        const Color.fromARGB(255, 58, 108, 149)
                            .withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
