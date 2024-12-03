import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class StatsScreen extends StatefulWidget {
  @override
  _StatsScreenState createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<Map<String, dynamic>> recentRuns = [];
  bool isLoading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchRecentRuns();
  }

  Future<void> _fetchRecentRuns() async {
    try {
      final response = await http.get(Uri.parse('https://app.dokkedalleth.dk/routes.php'));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success']) {
          setState(() {
            recentRuns = _processRuns(jsonData['routes']);
            isLoading = false;
          });
        } else {
          setState(() {
            print('Failed to load recent runs: ${jsonData['error']}');
            hasError = true;
            isLoading = false;
          });
        }
      } else {
        setState(() {
          print('Failed to load recent runs: ${response.statusCode}');
          hasError = true;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        print('Failed to load recent runs: $e');
        hasError = true;
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _processRuns(List<dynamic> runs) {
    return runs.map((run) {
      final totalTimeInSeconds = run['total_time'] is int
          ? run['total_time']
          : int.tryParse(run['total_time'].toString()) ?? 0;

      final totalDistanceInKm = run['total_distance'] is num
          ? run['total_distance'] / 1000
          : double.tryParse(run['total_distance'].toString()) ?? 0.0;

      return {
        'date': DateTime.parse(run['date']), // Parse the date string
        'distance': totalDistanceInKm,
        'time': totalTimeInSeconds,
      };
    }).toList();
  }

  int _calculateRunsLastWeek() {
    final DateTime now = DateTime.now();
    final DateTime oneWeekAgo = now.subtract(Duration(days: 7));
    return recentRuns.where((run) => run['date'].isAfter(oneWeekAgo) && run['date'].isBefore(now)).length;
  }

  double _calculateAveragePace() {
    final DateTime now = DateTime.now();
    final DateTime oneWeekAgo = now.subtract(Duration(days: 7));
    final lastWeekRuns = recentRuns
        .where((run) => run['date'].isAfter(oneWeekAgo) && run['date'].isBefore(now))
        .toList();

    if (lastWeekRuns.isEmpty) return 0.0;

    double totalDistance = 0.0;
    double totalTime = 0.0;

    for (var run in lastWeekRuns) {
      totalDistance += run['distance'];
      totalTime += run['time'];
    }

    return totalTime / 60 / totalDistance; // Average pace in min/km
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (hasError) {
      return Center(child: Text('Error loading stats. Please try again.'));
    }

    final int runsLastWeek = _calculateRunsLastWeek();
    final double averagePace = _calculateAveragePace();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detailed Stats',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          Text(
            'Runs completed last week: $runsLastWeek',
            style: TextStyle(fontSize: 18),
          ),
          SizedBox(height: 10),
          Text(
            'Average pace: ${averagePace.toStringAsFixed(2)} min/km',
            style: TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }
}