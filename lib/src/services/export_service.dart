import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/ride.dart';

class ExportService {
  static Future<File> exportGpx(Ride ride) async {
    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln(
      '<gpx version="1.1" creator="Velocity"'
      ' xmlns="http://www.topografix.com/GPX/1/1">',
    );
    buf.writeln('  <trk>');
    buf.writeln(
      '    <name>Ride ${ride.startTime.toIso8601String()}</name>',
    );
    buf.writeln('    <trkseg>');
    for (final pt in ride.points) {
      buf.writeln(
        '      <trkpt lat="${pt.latitude}" lon="${pt.longitude}">',
      );
      buf.writeln('        <ele>${pt.altitude.toStringAsFixed(1)}</ele>');
      buf.writeln(
        '        <time>${pt.timestamp.toUtc().toIso8601String()}</time>',
      );
      buf.writeln(
        '        <extensions><speed>${(pt.speedKmh / 3.6).toStringAsFixed(2)}</speed></extensions>',
      );
      buf.writeln('      </trkpt>');
    }
    buf.writeln('    </trkseg>');
    buf.writeln('  </trk>');
    buf.writeln('</gpx>');

    return _writeFile(ride.id, 'gpx', buf.toString());
  }

  static Future<File> exportTcx(Ride ride) async {
    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln(
      '<TrainingCenterDatabase'
      ' xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">',
    );
    buf.writeln('  <Activities>');
    buf.writeln('    <Activity Sport="Biking">');
    buf.writeln(
      '      <Id>${ride.startTime.toUtc().toIso8601String()}</Id>',
    );
    buf.writeln('      <Lap StartTime="${ride.startTime.toUtc().toIso8601String()}">');
    buf.writeln(
      '        <TotalTimeSeconds>${ride.duration.inSeconds}</TotalTimeSeconds>',
    );
    buf.writeln(
      '        <DistanceMeters>${(ride.distanceKm * 1000).toStringAsFixed(0)}</DistanceMeters>',
    );
    buf.writeln(
      '        <MaximumSpeed>${(ride.maxSpeedKmh / 3.6).toStringAsFixed(2)}</MaximumSpeed>',
    );
    buf.writeln('        <Track>');
    for (final pt in ride.points) {
      buf.writeln('          <Trackpoint>');
      buf.writeln(
        '            <Time>${pt.timestamp.toUtc().toIso8601String()}</Time>',
      );
      buf.writeln('            <Position>');
      buf.writeln(
        '              <LatitudeDegrees>${pt.latitude}</LatitudeDegrees>',
      );
      buf.writeln(
        '              <LongitudeDegrees>${pt.longitude}</LongitudeDegrees>',
      );
      buf.writeln('            </Position>');
      buf.writeln(
        '            <AltitudeMeters>${pt.altitude.toStringAsFixed(1)}</AltitudeMeters>',
      );
      buf.writeln(
        '            <Extensions><Speed>${(pt.speedKmh / 3.6).toStringAsFixed(2)}</Speed></Extensions>',
      );
      buf.writeln('          </Trackpoint>');
    }
    buf.writeln('        </Track>');
    buf.writeln('      </Lap>');
    buf.writeln('    </Activity>');
    buf.writeln('  </Activities>');
    buf.writeln('</TrainingCenterDatabase>');

    return _writeFile(ride.id, 'tcx', buf.toString());
  }

  static Future<File> _writeFile(
    String rideId,
    String ext,
    String content,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/velocity_$rideId.$ext');
    await file.writeAsString(content);
    return file;
  }
}
