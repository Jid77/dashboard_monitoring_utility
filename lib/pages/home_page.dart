import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:aplikasitest1/services/background_task_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:aplikasitest1/widgets/background_wave.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<FlSpot> _tk201Data = [];
  List<FlSpot> _tk202Data = [];
  List<FlSpot> _tk103Data = [];

  List<String> _timestamps = [];
  int _index = 0;
  late Timer _timer;
  late Box _sensorDataBox;
  late Box _alarmHistoryBox;
  final DateFormat formatter = DateFormat('HH:mm');

  final PageController _pageController = PageController();

  int _boilerStatus = 0;
  int _ofdaStatus = 0;
  int _oilessStatus = 0;

  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _sensorDataBox = Hive.box('sensorDataBox');
    _alarmHistoryBox = Hive.box('alarmHistoryBox');

    _loadDataFromHive();

    _timer = Timer.periodic(Duration(minutes: 1), (timer) {
      _fetchData();
    });

    _fetchData();
  }

  void _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    final dataSnapshot = await _database.child('sensor_data').get();
    if (dataSnapshot.value != null) {
      final data = Map<dynamic, dynamic>.from(dataSnapshot.value as Map);
      final tk201 = data['tk201']?.toDouble() ?? 0;
      final tk202 = data['tk202']?.toDouble() ?? 0;
      final tk103 = data['tk103']?.toDouble() ?? 0;
      final boiler = data['boiler'] ?? 0;
      final ofda = data['ofda'] ?? 0;
      final oiless = data['oiless'] ?? 0;
      final timestamp = DateTime.now();
      // Cek kondisi alarm, jika data sensor keluar dari range maka kirim notifikasi
      await checkAlarmCondition(
          tk201, tk202, tk103, boiler, ofda, oiless, timestamp);

      setState(() {
        _index++;
        _tk201Data.add(FlSpot(_index.toDouble(), tk201));
        _tk202Data.add(FlSpot(_index.toDouble(), tk202));
        _tk103Data.add(FlSpot(_index.toDouble(), tk103));
        _timestamps.add(formatter.format(timestamp));

        _boilerStatus = boiler;
        _ofdaStatus = ofda;
        _oilessStatus = oiless;

        _isLoading = false;
      });

      _sensorDataBox.put('tk201_$_index', tk201);
      _sensorDataBox.put('tk202_$_index', tk202);
      _sensorDataBox.put('tk103_$_index', tk103);
      _sensorDataBox.put('timestamp_$_index', timestamp.toIso8601String());
      _sensorDataBox.put('boiler', boiler);
      _sensorDataBox.put('ofda', ofda);
      _sensorDataBox.put('oiless', oiless);
    }
  }

  void _loadDataFromHive() {
    for (int i = 1; i <= _sensorDataBox.length ~/ 3; i++) {
      double? temp201 = _sensorDataBox.get('tk201_$i');
      double? temp202 = _sensorDataBox.get('tk202_$i');
      double? temp103 = _sensorDataBox.get('tk103_$i');

      String? time = _sensorDataBox.get('timestamp_$i');
      if (temp201 != null &&
          temp202 != null &&
          temp103 != null &&
          time != null) {
        _tk201Data.add(FlSpot(i.toDouble(), temp201));
        _tk202Data.add(FlSpot(i.toDouble(), temp202));
        _tk103Data.add(FlSpot(i.toDouble(), temp103));
        _timestamps.add(formatter.format(DateTime.parse(time)));
      }
    }
    _index = _sensorDataBox.length ~/ 3;
  }

  void _onBottomNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Menempatkan Custom AppBar di belakang konten
          ClipPath(
            clipper: BackgroundWaveClipper(),
            child: Container(
              height: 210,
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                colors: [Color(0xFFFFB1D7), Color(0xFFFFEAF0)],
              )),
              child: Center(),
            ),
          ),
          // Konten utama
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              // Menggunakan Center untuk memposisikan teks di tengah
              child: Text(
                'Utility Monitoring Dashboard',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          _selectedIndex == 0 ? _buildHomeContent() : _buildHistoryContent(),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: _onBottomNavTapped,
                items: [
                  BottomNavigationBarItem(
                    icon: SvgPicture.asset(
                      'assets/images/homefull.svg',
                      color: _selectedIndex == 0
                          ? Color(0xFFed4d9b)
                          : Colors.black54, // Ubah warna saat dipilih
                      width: 20,
                      height: 20,
                    ),
                    label: 'Home',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.history_sharp, size: 26),
                    label: 'History',
                  ),
                ],
                selectedItemColor: Color(0xFFed4d9b),
                unselectedItemColor: Colors.black54,
                backgroundColor: Colors.transparent,
                elevation: 0,
                type: BottomNavigationBarType.fixed,
                // selectedLabelStyle: TextStyle(
                //   fontWeight: FontWeight.bold,
                // ),
                // unselectedLabelStyle: TextStyle(
                //   fontWeight: FontWeight.w600,
                // ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryContent() {
    return Padding(
      padding:
          const EdgeInsets.only(top: 150.0), // Sesuaikan dengan tinggi app bar

      child: ValueListenableBuilder(
        valueListenable: _alarmHistoryBox.listenable(),
        builder: (context, Box box, _) {
          final alarmEntries = box.toMap().entries.toList();

          // Mengurutkan alarm berdasarkan timestamp, terbaru di atas
          alarmEntries.sort((a, b) {
            DateTime timestampA = a.value['timestamp'] is String
                ? DateTime.parse(a.value['timestamp'])
                : a.value['timestamp'];
            DateTime timestampB = b.value['timestamp'] is String
                ? DateTime.parse(b.value['timestamp'])
                : b.value['timestamp'];
            return timestampB.compareTo(timestampA);
          });

          return ListView.builder(
            itemCount: alarmEntries.length,
            itemBuilder: (context, index) {
              final entry = alarmEntries[index];
              final key = entry.key; // Mengambil kunci dari item
              final alarm = entry.value;

              // Format timestamp ke string sederhana
              String formattedTimestamp = alarm['timestamp'] is DateTime
                  ? DateFormat('MMMM dd, yyyy HH:mm WIB')
                      .format(alarm['timestamp'])
                  : alarm['timestamp'];
              // Menampilkan nama alarm dan nilai sensor di judul
              String title = '${alarm['alarmName']} - ${alarm['sensorValue']}°';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(35), // Rounded corners
                ),
                color: const Color.fromARGB(255, 255, 255, 255),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: const Color.fromARGB(255, 0, 0, 0),
                    ),
                  ),
                  subtitle: Text(
                    '$formattedTimestamp',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: const Color(0xFFed4d9b)),
                    onPressed: () {
                      // Menghapus alarm dari Hive menggunakan kunci yang tepat
                      box.delete(key);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHomeContent() {
    return _isLoading
        ? Center(
            child:
                CircularProgressIndicator(), // Display loading indicator when fetching data
          )
        : Padding(
            padding: const EdgeInsets.only(
                top: 150.0), // Sesuaikan dengan tinggi app bar
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    children: [
                      // Halaman pertama: Boiler,Oiless
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SingleChildScrollView(
                          // Tambahkan SingleChildScrollView di sini
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: SingleChildScrollView(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              // Box untuk status Boiler
                                              Container(
                                                padding: EdgeInsets.all(16.0),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          40.0),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.grey
                                                          .withOpacity(0.3),
                                                      spreadRadius: 2,
                                                      blurRadius: 8,
                                                      offset: Offset(0, 3),
                                                    ),
                                                  ],
                                                ),
                                                child: _buildStatusWidget(
                                                    'Boiler',
                                                    _boilerStatus,
                                                    'assets/images/boiler.png',
                                                    140,
                                                    200), // Menambahkan assetImage
                                              ),
                                              SizedBox(
                                                  height:
                                                      36), // Spasi antar box
                                              // Box untuk status Oiless
                                              Container(
                                                padding: EdgeInsets.all(16.0),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          40.0),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.grey
                                                          .withOpacity(0.3),
                                                      spreadRadius: 2,
                                                      blurRadius: 8,
                                                      offset: Offset(0, 3),
                                                    ),
                                                  ],
                                                ),
                                                child: _buildStatusWidget(
                                                    'Oiless',
                                                    _oilessStatus,
                                                    'assets/images/air-compressor.png',
                                                    120,
                                                    150), // Menambahkan assetImage
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Halaman kedua: Current Temperature dan Graphic Temperature
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 25.0, left: 16, right: 16, bottom: 16),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                    vertical: 8.0, horizontal: 16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Temperature Vent Filter",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                      textAlign: TextAlign.start,
                                    ),
                                    SizedBox(
                                        height:
                                            4), // Jarak antara teks dan garis
                                    Divider(
                                      thickness: 2, // Ketebalan garis
                                      color: Colors.black, // Warna garis
                                      indent: 0, // Jarak dari tepi kiri
                                      endIndent: 150, // Jarak dari tepi kanan
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 10),

                              // Container for Current Temperature display
                              Container(
                                padding: EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.3),
                                      spreadRadius: 2,
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Current Temperature",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildCircularValue(
                                          'Tk201',
                                          _tk201Data.isNotEmpty
                                              ? _tk201Data.last.y
                                              : 0,
                                        ),
                                        _buildCircularValue(
                                          'Tk202',
                                          _tk202Data.isNotEmpty
                                              ? _tk202Data.last.y
                                              : 0,
                                        ),
                                        _buildCircularValue(
                                          'Tk103',
                                          _tk103Data.isNotEmpty
                                              ? _tk103Data.last.y
                                              : 0,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16),

                              // Title and Chart
                              Text(
                                "Graphic Temperature",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 16),
                              _buildChart(),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                // Smooth Page Indicator
                Padding(
                  padding: const EdgeInsets.only(
                      bottom: 76.0), // Atur jarak sesuai kebutuhan
                  child: SmoothPageIndicator(
                    controller: _pageController,
                    count: 4, // Jumlah halaman yang ada di PageView
                    effect: WormEffect(
                      dotHeight: 8.0,
                      dotWidth: 8.0,
                      activeDotColor: Color(0xFFed4d9b),
                      dotColor: Colors.grey.withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildStatusWidget(String label, int status, String assetImage,
      double imageWidth, double imageHeight) {
    return Container(
      width: 110, // Increased width for better readability
      height: 200,
      padding: EdgeInsets.all(10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Gambar di sebelah kiri
          Image.asset(
            assetImage, // Menggunakan parameter untuk path gambar
            width: imageWidth, // Ukuran gambar boiler
            height: imageHeight,
          ),
          SizedBox(width: 10), // Jarak antara gambar dan teks
          // Teks di sebelah kanan
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center, // Memusatkan teks secara vertikal
              crossAxisAlignment: CrossAxisAlignment
                  .center, // Memposisikan teks di sebelah kiri
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    color: status == 1
                        ? Color(0xFF6FCF97) // Warna hijau untuk status normal
                        : Color(
                            0xFFFF6B6B), // Warna merah untuk status abnormal
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    status == 1 ? "Normal" : "Abnormal", // Teks status
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    // Menghitung waktu satu jam yang lalu
    DateTime now = DateTime.now();
    DateTime oneHourAgo = now.subtract(Duration(hours: 1));

    // Filter data berdasarkan waktu satu jam terakhir
    List<FlSpot> filteredTk201Data = _tk201Data
        .where((spot) => DateTime.fromMillisecondsSinceEpoch(spot.x.toInt())
            .isAfter(oneHourAgo))
        .toList();

    List<FlSpot> filteredTk202Data = _tk202Data
        .where((spot) => DateTime.fromMillisecondsSinceEpoch(spot.x.toInt())
            .isAfter(oneHourAgo))
        .toList();

    List<FlSpot> filteredTk103Data = _tk103Data
        .where((spot) => DateTime.fromMillisecondsSinceEpoch(spot.x.toInt())
            .isAfter(oneHourAgo))
        .toList();

    // Menentukan maxX dan minX
    double maxX = filteredTk201Data.isNotEmpty
        ? filteredTk201Data.last.x
        : 50; // Set default jika tidak ada data
    double minX = filteredTk201Data.isNotEmpty
        ? filteredTk201Data.first.x
        : 0; // Set minX ke 0 jika tidak ada data

    // Jika data kurang dari satu jam, reset minX dan maxX
    if (filteredTk201Data.isEmpty) {
      maxX = 50; // Atur maxX ke nilai default
      minX = 0; // Mulai dari 0
    }

    return Container(
      height: 300, // Tinggi kontainer grafik
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            flex: 8,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: true,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.5),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.5),
                      strokeWidth: 0.5,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        // Menampilkan timestamp sebagai label
                        DateTime timestamp =
                            DateTime.fromMillisecondsSinceEpoch(value.toInt());
                        return Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: Text(
                            "${timestamp.hour}:${timestamp.minute}",
                            style: TextStyle(color: Colors.black, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(
                              top: 20, left: 10, bottom: 20),
                          child: Text(
                            value.toInt().toString(),
                            style: TextStyle(color: Colors.black, fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.black, width: 1),
                ),
                minX: minX,
                maxX: maxX, // Set maxX berdasarkan data yang sudah difilter
                minY: 65,
                maxY: 85,
                lineBarsData: [
                  LineChartBarData(
                    spots: filteredTk201Data,
                    isCurved: true,
                    curveSmoothness: 1.0,
                    barWidth: 2,
                    color: Color(0xFFed4d9b),
                    dotData: FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: filteredTk202Data,
                    isCurved: true,
                    curveSmoothness: 1.0,
                    barWidth: 2,
                    color: Color(0xFF9C27B0),
                    dotData: FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: filteredTk103Data,
                    isCurved: true,
                    curveSmoothness: 1.0,
                    barWidth: 2,
                    color: Color(0xFFC6849B),
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegend(color: Color(0xFFed4d9b), label: 'Tk201'),
              _buildLegend(color: Color(0xFF9C27B0), label: 'Tk202'),
              _buildLegend(color: Color(0xFFC6849B), label: 'Tk103'),
            ],
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildValueWidget(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularValue(String label, double value) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Color(0xFF8547b0), // Ganti warna sesuai kebutuhan
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${value.toInt()}°C',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLegend({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
