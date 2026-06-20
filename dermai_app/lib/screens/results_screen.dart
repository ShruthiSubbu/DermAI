import 'package:flutter/material.dart';
import 'dart:typed_data';

class ResultsScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  final Uint8List imageBytes;

  const ResultsScreen({super.key, required this.result, required this.imageBytes});

  @override
  Widget build(BuildContext context) {
    final prediction = result['prediction'] ?? 'Unknown';
    final confidence = (result['confidence'] ?? 0).toStringAsFixed(1);
    final top5 = result['top5'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Results'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(imageBytes, height: 200, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Top Prediction', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(prediction, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Confidence: ', style: TextStyle(color: Colors.grey)),
                      Text('$confidence%', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Top 5 Predictions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...top5.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value as Map<String, dynamic>;
              final conf = (item['confidence'] ?? 0).toStringAsFixed(1);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: idx == 0 ? const Color(0xFF4CAF50) : Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('${idx + 1}',
                            style: TextStyle(color: idx == 0 ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(item['condition'] ?? '', style: const TextStyle(fontSize: 14))),
                    Text('$conf%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            const Text(
              '⚠️ This is not a medical diagnosis. Please consult a dermatologist for professional advice.',
              style: TextStyle(color: Colors.orange, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}