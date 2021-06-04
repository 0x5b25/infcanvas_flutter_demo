
import 'package:flutter/material.dart';


class InputBox extends StatelessWidget {

  final String hint;
  final Function(String)? onChange;
  final TextEditingController? ctrl;
  final String? errorMessage;

  InputBox({
    Key? key,
    this.hint = "Filter...",
    this.onChange,
    this.ctrl,
    this.errorMessage,
  }):super(key: key);

  @override
  Widget build(BuildContext context) {

    var _ctrl = ctrl??TextEditingController();

    return TextField(
      controller: _ctrl,
      decoration: new InputDecoration(
        errorText: errorMessage,
        border: new OutlineInputBorder(
          borderRadius: const BorderRadius.all(
            const Radius.circular(4.0),
          ),
        ),
        suffixIcon: TextButton(
          child:Icon(Icons.close ,),
          onPressed: (){
            var val = _ctrl.text;
            if(val == "") return;
            _ctrl.clear();
            onChange?.call("");
          },
        ),
        suffixIconConstraints: BoxConstraints(maxHeight: 30, maxWidth: 30),
        isDense: true,
        contentPadding: EdgeInsets.all(8),
        filled: true,
        hintText: hint,
      ),
      onChanged: (s){onChange?.call(s);},
    );
  }
}

class _ValidatableTextInput extends StatefulWidget {
  final String title;
  final String? hint;
  final String? initialText;
  final String? Function(String)? validator;
  const _ValidatableTextInput({
    Key? key,
    required this.title,
    this.hint,
    this.initialText,
    this.validator
  }) : super(key: key);

  @override
  _ValidatableTextInputState createState() => _ValidatableTextInputState();
}

class _ValidatableTextInputState extends State<_ValidatableTextInput> {

  String? errMsg;
  var ctrl = TextEditingController();

  @override void initState() {
    super.initState();
    ctrl.text = widget.initialText??"";
  }

  @override void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(widget.initialText != oldWidget.initialText){
      ctrl.text = widget.initialText??"";
    }
  }

  @override void dispose() {
    super.dispose();
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    return AlertDialog(
      title: Text(widget.title),
      content: InputBox(
        hint: widget.hint??"Enter...",
        errorMessage: errMsg,
        ctrl: ctrl,
        onChange: (s){
          var msg = widget.validator?.call(s);
          if(msg!=errMsg){
            errMsg = msg;
            setState(() {});
          }
        },
      ),
      actions: [
        TextButton(
          child: Text("OK"),
          onPressed:
            errMsg != null?null:
          (){
            Navigator.of(ctx).pop(ctrl.text);
          },
        ),
        TextButton(
          child: Text("Cancel"),
          onPressed: (){
            Navigator.of(ctx).pop(null);
          },
        ),
      ],
    );
  }
}


Future<String?> RequestTextInput(BuildContext ctx, String title, {
  String? hint,
  String? initialText,
  String? Function(String)? validator
})async{
  var ctrl = TextEditingController(text:initialText);
  String? name = await showDialog(
    context:  ctx,
    builder: (_)=>_ValidatableTextInput(
      title: title,
      hint: hint,
      initialText: initialText,
      validator: validator,
    )
  );
  return name;
}

