
import 'package:flutter/material.dart';

class NameField extends StatefulWidget{
  String? initialText;
  String? hint;
  ///Also a validation function
  bool Function(String)? onChange;

  NameField({Key? key, this.onChange, this.initialText, this.hint})
  :super(key: key){ }

  @override
  _NameFieldState createState() => _NameFieldState();
}

class _NameFieldState extends State<NameField> {

  bool hasErr = false;
  var fieldNameCtrl = TextEditingController();

  @override
  void initState(){
    super.initState();
    if(widget.initialText != null)
      fieldNameCtrl..text = widget.initialText!;
  }

  @override
  void didUpdateWidget(NameField oldWidget){
    super.didUpdateWidget(oldWidget);
    //fieldNameCtrl.value.selection
    var name = widget.initialText;
    if(name == null) return;
    if(name != fieldNameCtrl.text){
      fieldNameCtrl.value = 
        fieldNameCtrl.value.copyWith(
          text: name, 
          selection: TextSelection.collapsed(offset: name.length)
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: fieldNameCtrl,
      
      decoration: InputDecoration(
        //errorText: nameHasError?"Invalid name":null,
        enabledBorder: hasErr?OutlineInputBorder(
          borderSide: BorderSide(width: 2,color: Colors.red)
        ):null,
        disabledBorder:  hasErr?OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red)
        ):null,
        focusedBorder:  hasErr?OutlineInputBorder(
          borderSide: BorderSide(width: 2, color: Colors.red)
        ):null,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.only(left: 4, bottom: 0, top: 0, right: 4),
        hintText: widget.hint,
      ),
      onChanged: (str){
        if(widget.onChange == null) return;
        setState(() {
          hasErr = !widget.onChange!(str);
        });
      },
    );
  }
}