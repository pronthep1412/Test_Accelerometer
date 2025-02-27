import 'package:flutter/material.dart';

class DetectionStatusCard extends StatelessWidget {
  final String status;
  final bool isActive;
  final VoidCallback? onTap;

  const DetectionStatusCard({
    super.key,
    required this.status,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? Colors.green.shade300 : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isActive ? Colors.green.shade50 : Colors.grey.shade50,
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isActive ? Colors.green : Colors.grey,
                radius: 24,
                child: Icon(
                  isActive ? Icons.check_circle : Icons.info,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isActive ? 'กำลังทำงาน' : 'ไม่ได้ทำงาน',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isActive
                            ? Colors.green.shade700
                            : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 14,
                        color: isActive
                            ? Colors.green.shade900
                            : Colors.grey.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios,
                  color:
                      isActive ? Colors.green.shade400 : Colors.grey.shade400,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
