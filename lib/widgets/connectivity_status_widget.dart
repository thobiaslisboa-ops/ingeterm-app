import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityStatusWidget extends StatelessWidget {
  final Widget child;

  const ConnectivityStatusWidget({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      initialData: [ConnectivityResult.wifi],
      builder: (context, snapshot) {
        final isOnline = snapshot.data?.isNotEmpty == true && 
          !(snapshot.data?.every((r) => r == ConnectivityResult.none) ?? true);

        return Stack(
          children: [
            child,
            if (!isOnline)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.cloud_off,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'MODO OFFLINE - Los datos se guardarán localmente y se sincronizarán cuando haya internet',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
