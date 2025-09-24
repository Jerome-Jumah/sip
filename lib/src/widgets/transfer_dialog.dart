import 'package:flutter/material.dart';

class TransferCallDialog extends StatelessWidget {
  const TransferCallDialog({
    super.key,
    required this.onOk,
    required this.onTransferTarget,
  });

  final void Function(String)? onTransferTarget;
  final void Function() onOk;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Enter target to transfer.'),
      content: TextField(
        onChanged: onTransferTarget,
        decoration: InputDecoration(hintText: 'URI or Username'),
        textAlign: TextAlign.center,
      ),
      actions: <Widget>[
        TextButton(onPressed: onOk, child: Text('Ok')),
        TextButton(
          child: Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
