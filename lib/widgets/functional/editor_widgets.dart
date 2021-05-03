
import 'package:flutter/material.dart';


class PushButton extends StatelessWidget {

  bool state;
  Widget child;
  void Function(bool) onChange;

  PushButton({
    Key?key,
    required this.state,
    required this.child,
    required this.onChange,
  }):super(key: key){}

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: (){
        onChange(!state);
      },
      child: child,
    );
  }

  PushButton.text(
    String content,
    {
      Key?key,
      required this.state,
      required this.onChange,
    }
  ):child = Text(content,
              style: state?
              TextStyle(color: Colors.green):
              TextStyle(color: Colors.grey),
            )
  { }
}

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

///Non-editable property can return null in editmode
abstract class ListEntryProperty{
  Widget Build(BuildContext ctx);
  Widget? BuildEditMode(BuildContext ctx)=>null;
}

abstract class ListEditEntry{
  late ListInterface iface;

  bool CanEdit();
  bool IsConfigValid();
  Iterable<ListEntryProperty> EditableProps(BuildContext ctx);
}

abstract class ListInterface{
  Iterable<ListEditEntry> GetEntry()sync*{
    for(var entry in doGetEntry()){
      entry.iface = this;
      yield entry;
    }
  }
  void Init(BuildContext ctx){}
  Iterable<ListEditEntry> doGetEntry();
  void RemoveEntry(covariant ListEditEntry entry);
  void AddEntry(covariant ListEditEntry entry);

  bool get canAdd =>true;
  bool get canRemove =>true;

  ListEditEntry GiveEntryTemplate(){
    var entry = doCreateEntryTemplate();
    entry.iface = this;
    return entry;
  }
  ListEditEntry doCreateEntryTemplate();
}


class _NewEntryButton extends StatefulWidget {

  ListEditEntry Function() template;
  void Function(ListEditEntry) addEntry;

  _NewEntryButton(this.template, this.addEntry);

  @override
  _NewEntryButtonState createState() => _NewEntryButtonState();
}

class _NewEntryButtonState extends State<_NewEntryButton> {
  ListEditEntry? newEntry;
  bool configHasError = false;

  bool get inEditMode => newEntry != null;

  Map<_ValidatePropState, bool> stats = {};


  void CheckConfigStatus(){
    var stat = !newEntry!.IsConfigValid();
    if(stat == configHasError ) return;
    setState(() {
      configHasError = stat;
    });
  }


  void _RequestNewEntry(){
    newEntry = widget.template();
    configHasError = !newEntry!.IsConfigValid();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: inEditMode?
      _showFieldEditor():
      _showAddButton()
    );
  }

  Widget _showAddButton(){
    return TextButton(
      onPressed: (){setState(() {
        _RequestNewEntry();
      });},
      child: Icon(Icons.add),
    );
  }

  Widget _showFieldEditor(){
    List<Widget> props = [];
    for(var p in newEntry!.EditableProps(context)){
      var e = p.BuildEditMode(context);
      if(e != null)
        props.add(e);
      else
        props.add(p.Build(context));
    }

    return Container(
      height: 30,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          
          Expanded(
            child:Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: props,
            )
          ),
          
          SizedBox( width: 30, height: 30,
            child: TextButton(
              onPressed: configHasError? Reset:AddEntry,
              child: configHasError?
              Icon(Icons.close, color: Colors.red,):
              Icon(Icons.check, color: Colors.green,),
            ),
          ),
        ],
      ),
    );
  }

  void Reset(){
    setState(() {
      stats = {};
      newEntry = null;
    });
  }

  void AddEntry(){
    if(configHasError)return;
    setState(() {
      stats = {};
      widget.addEntry(newEntry!);
      newEntry = null;
    });
  }
}



class ListEditor extends StatefulWidget {

  String title;
  ListInterface listToEdit;
  void Function(ListEditEntry?)? onSelect, onDelete;
  bool canEdit;

  ListEditor({
    Key? key,
    this.title = '',
    required this.listToEdit,
    this.onSelect,
    this.canEdit = true,
  }){

  }

  @override
  _ListEditorState createState() => _ListEditorState();
}

class _ListEditorState extends State<ListEditor> {

  bool _inEditMode = false;
  int _sel = -1;

  @override
  void didUpdateWidget(ListEditor oldWidget){
    super.didUpdateWidget(oldWidget);
    if(oldWidget.listToEdit != widget.listToEdit)
      widget.listToEdit.Init(context);
  }

  @override
  void didChangeDependencies(){
    super.didChangeDependencies();
    widget.listToEdit.Init(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4),
          child: Container(
            height: 30,
            child: Row(
              //crossAxisAlignment: CrossAxisAlignment.center,
              //mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(child: Text(widget.title)),
                if(widget.canEdit)
                  SizedBox(width: 30, height: 30,
                    child:TextButton(
                      onPressed: (){
                        setState(() {
                          _inEditMode = !_inEditMode;
                        });
                      },
                      child: _inEditMode?
                      Icon(Icons.check,color: Colors.green,):
                      Icon(Icons.edit,),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Divider(),
        for(var w in _BuildEntry())
          Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: SizedBox(
              height: 30,
              child: w
            ),
          ),
        if(_inEditMode && widget.listToEdit.canAdd)
          _NewEntryButton(
            widget.listToEdit.GiveEntryTemplate, 
            (e){
              setState(() {
                widget.listToEdit.AddEntry(e);
              });
            } 
          ),
      ],
    );
  }

  Iterable<Widget> _BuildEntry()sync*{
    int i = 0;
    for(var entry in widget.listToEdit.GetEntry()){
      i++;
      if(!_inEditMode) {
        yield _BuildNormalEntry(entry,i);
        continue;
      }

      if(entry.CanEdit())
        yield _BuildEditEntry(entry,i);
      else
        yield _BuildInfoEntry(entry);
      
    }    
  }

  Widget _BuildInfoEntry(ListEditEntry entry){
    var props = <Widget>[];
    for(var p in entry.EditableProps(context)){
      props.add(p.Build(context));
    }

    return Padding(
      padding: EdgeInsets.only(left: 4, right: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: props,
      ),
    );
  }

  Widget _BuildNormalEntry(ListEditEntry entry, int idx){
    var selColor = Theme.of(context).primaryColor.withOpacity(0.2);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: (){
        if(widget.onSelect != null){
          SelectFocus(idx);
          widget.onSelect!.call(entry);
        }
      },
      child: Container(
        color: _sel == idx?selColor:null,
        child: _BuildInfoEntry(entry),
      ),
    );
  }

  Widget _BuildEditEntry(ListEditEntry entry, int idx){
    var props = <Widget>[];
    for(var p in entry.EditableProps(context)){
      var e = p.BuildEditMode(context);
      if(e != null)
        props.add(e);
      else
        props.add(p.Build(context));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children:[
        if(widget.listToEdit.canRemove)
          SizedBox( width: 30, //height: 30,
            child: TextButton(
              onPressed: (){RemoveEntry(entry, idx);},
              child:Icon(Icons.delete, color: Colors.red,),
            ),
          ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: props,
          ),
        ),
      ]
    );
  }

  void RemoveEntry(ListEditEntry entry, int idx){
    if(_sel == idx){
      _sel = -1;
    }

    widget.listToEdit.RemoveEntry(entry);
    widget.onDelete?.call(entry);
    setState(() {});
  }

  void SelectFocus(int idx) {
    if(_sel == idx) return;
    setState(() {
      _sel = idx;
    });
  }
}


abstract class _ValidatePropState<T extends StatefulWidget> extends State<T>{

  late _NewEntryButtonState? entButton;

  @override @mustCallSuper
  void didChangeDependencies(){
    super.didChangeDependencies();
    entButton = context.findAncestorStateOfType<_NewEntryButtonState>();
    //entButton?._RegConfigStat(this, false);
  }

}

class StringPropEditor extends StatefulWidget {

  String? initialContent;
  String? hint;
  bool Function(String) onChange;

  StringPropEditor(this.onChange, {this.initialContent, this.hint});

  @override
  _StringPropEditorState createState() => _StringPropEditorState();
}

class _StringPropEditorState extends _ValidatePropState<StringPropEditor> {
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: NameField(
        initialText: widget.initialContent,
        hint: widget.hint,
        onChange: (name){
          bool isValid = widget.onChange(name);
          entButton?.CheckConfigStatus();
          return isValid;
        },
      ),
    );
  }
}

class StringProp extends ListEntryProperty{
  String? initialContent;
  String? hint;
  bool Function(String) onChange;

  StringProp(this.onChange, {this.initialContent, this.hint});

  @override
  Widget Build(BuildContext ctx) {
    return Expanded(child: Text(initialContent??""));
  }

  @override
  Widget? BuildEditMode(BuildContext ctx){
    return StringPropEditor(
      onChange, 
      initialContent: initialContent,
      hint:hint
    );
  }

}

class SelectionPropEditor<T> extends StatefulWidget {
  
  Iterable<T> Function() requestSelections;
  T? initialValue;
  String? hint;
  void Function(T?) onSelect;
  String Function(T? obj)? displayName;

  SelectionPropEditor(
    {
      Key? key,
      this.hint,
      required this.requestSelections,
      required this.onSelect,
      this.initialValue,
      this.displayName,
    }
  ):super(key: key);

  @override
  _SelectionPropEditorState createState() => _SelectionPropEditorState<T>();
}

class _SelectionPropEditorState<T> extends _ValidatePropState<SelectionPropEditor<T>> {
  
  
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          hint: widget.hint == null?null:Text(widget.hint!),
          isExpanded: true,
          value: _checkValAvail(widget.initialValue)?widget.initialValue:null,
          onChanged: (T? newValue) {
            widget.onSelect(newValue);
            entButton?.CheckConfigStatus();
          },
          items: _getMenuItem(),
        ),
      ),
    );
  }

  

  bool _checkValAvail(T? val){
    if(val == null) return false;
    return widget.requestSelections().contains(val);
  }

  List<DropdownMenuItem<T>> _getMenuItem(){
    return widget.requestSelections().map<DropdownMenuItem<T>>((T value) {
      return DropdownMenuItem<T>(
        value: value,
        child: Text(widget.displayName?.call(value)??value.toString()),
      );
    }).toList();
  }

}


class SelectionProp<T> extends ListEntryProperty{
  Iterable<T> Function() requestSelections;
  T? initialValue;
  void Function(T?) onSelect;
  String? hint;
  String Function(T o)? displayName;

  SelectionProp(
    {
      required this.requestSelections,
      required this.onSelect,
      this.initialValue,
      this.hint,
      this.displayName,
    }
  );

  String _valToString(T? o){
    if(o == null) return "empty";
    if(displayName != null) 
      return displayName!(o);
    return o.toString();
  } 

  @override
  Widget Build(BuildContext ctx) {
    return Text(_valToString(initialValue),
      style:TextStyle(fontStyle: FontStyle.italic)
    );
  }

  @override
  Widget? BuildEditMode(BuildContext ctx){
    return Expanded(
      child: SelectionPropEditor(
        requestSelections: requestSelections,
        onSelect: onSelect,
        initialValue: initialValue,
        hint: hint,
        displayName: _valToString,
      ),
    );
  }

}

class BoolProp extends ListEntryProperty{

  String name;
  bool value;
  void Function(bool) onChange;

  BoolProp(
    this.name,
    this.value,
    this.onChange
  ){}

  @override
  Widget Build(BuildContext ctx) {
    return SizedBox(
      width: 30,
      height: 30,
      child: Center(
        child: Text(name,
          style: TextStyle(color: value?
            Colors.green:
            Colors.grey        
          ),
        ),
      ),
    );
  }

  @override
  Widget? BuildEditMode(BuildContext ctx){
    return SizedBox(
      height: 30,
      width: 30,
      child: PushButton.text(
        name, 
        state:value,
        onChange:onChange
      ),
    );
  }

}

class PropBuilder extends ListEntryProperty{

  Widget Function(BuildContext ctx) builder;
  Widget Function(BuildContext ctx)? editBuilder;

  PropBuilder({
    required this.builder,
    this.editBuilder
  }){}

  @override
  Widget Build(BuildContext ctx) {
    return builder(ctx);
  }

  @override
  Widget? BuildEditMode(BuildContext ctx){
    return editBuilder?.call(ctx);
  }
}

enum EntryStatus{
  Error, Warning, Normal, Unknown
}

class StatusIndicator extends ListEntryProperty{
  EntryStatus stat;
  StatusIndicator(this.stat);

  @override
  Widget Build(BuildContext ctx) {
    late IconData icon;
    Color color = Theme.of(ctx).indicatorColor;
    switch(stat){
      
      case EntryStatus.Error:icon = Icons.error; color = Colors.red; break;
      case EntryStatus.Warning:icon = Icons.warning; color = Colors.amber; break;
      case EntryStatus.Normal:icon = Icons.check; color = Colors.green; break;
      case EntryStatus.Unknown:icon = Icons.help_outline; break;
    }
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: Icon(
          icon, color: color, size: 16,
        ),
      ),
    );
  }

}
