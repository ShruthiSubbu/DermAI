import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  String _formatDate(Timestamp? ts) {
    if (ts == null) return 'Date unknown';
    final d = ts.toDate();
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year}  $h:$m';
  }

  Uint8List? _decodeHeatmap(dynamic value) {
    if (value is String && value.isNotEmpty) {
      try {
        return base64Decode(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void _showDetails(BuildContext context, Map<String, dynamic> data) {
    final prediction = (data['prediction'] ?? 'Unknown').toString();
    final confidence = ((data['confidence'] ?? 0) as num).toDouble();
    final timestamp = data['timestamp'] as Timestamp?;
    final top5 = (data['top5'] as List?) ?? [];
    final heatmap = _decodeHeatmap(data['gradcam']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Top Prediction', style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 4),
              Text(prediction, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
              const SizedBox(height: 8),
              Text(
                'Confidence: ${confidence.toStringAsFixed(1)}%',
                style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(_formatDate(timestamp), style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              const Text('AI Attention Heatmap', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('Warm colours show where the AI looked most.',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 10),
              if (heatmap != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    heatmap,
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                    gaplessPlayback: true,
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Heatmap was not saved for this scan.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              const SizedBox(height: 20),
              const Text('Top 5 Predictions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              ...List.generate(top5.length, (i) {
                final item = Map<String, dynamic>.from(top5[i] as Map);
                final name = (item['condition'] ?? '').toString();
                final conf = ((item['confidence'] ?? 0) as num).toDouble();
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: i == 0 ? const Color(0xFF4CAF50) : Colors.grey[300],
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(color: i == 0 ? Colors.white : Colors.black87, fontSize: 12),
                    ),
                  ),
                  title: Text(name),
                  trailing: Text('${conf.toStringAsFixed(1)}%'),
                );
              }),
              const SizedBox(height: 12),
              const Text(
                'This is not a medical diagnosis. Please consult a dermatologist for professional advice.',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? const Center(child: Text('Not logged in'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('scans')
                  .where('uid', isEqualTo: user.uid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: SelectableText(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 60, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No scans yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final prediction = data['prediction'] ?? 'Unknown';
                    final confidence = ((data['confidence'] ?? 0) as num).toDouble().toStringAsFixed(1);
                    final timestamp = data['timestamp'] as Timestamp?;
                    final date = timestamp != null
                        ? '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}'
                        : 'Date unknown';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        onTap: () => _showDetails(context, data),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF4CAF50),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          prediction,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        subtitle: Text('Confidence: $confidence%  \u2022  $date'),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}