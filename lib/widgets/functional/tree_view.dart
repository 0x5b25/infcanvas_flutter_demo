
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:infcanvas/widgets/functional/popup.dart';
import 'package:infcanvas/widgets/visual/buttons.dart';
import 'package:infcanvas/widgets/visual/text_input.dart';

abstract class ContentAction{
  String get name;
  void PerformAction(_TreeViewWidgetState state, IContent content);
  const ContentAction();
}


class ContentActionDelegate extends ContentAction{
  final String name;
  final void Function(_TreeViewWidgetState, IContent) action;
  const ContentActionDelegate(this.name, this.action);
  void PerformAction(state, content){
    action(state, content);
  }
}

abstract class IContent{
  String get name;
  Widget? get thumbnail;
  bool get canModify;

  void Rename(String newName);
  void CopyTo(IContentProvider where);

  Iterable<ContentAction> get customActions => [];

  ContentAction? get defaultAction;

  @override toString()=>name;

  void Dispose(){}
}

abstract class IContentProvider extends IContent{
  Iterable<IContent> get content;

  void RemoveChild(IContent which);
  void MoveChildTo(IContent which, IContentProvider where);
  void CreateSubProvider(String name);

  @override Dispose(){
    for(var c in content){
      c.Dispose();
    }
  }

  @override get defaultAction => ContentActionDelegate(
    "Open",
    (state,_){state.PushPath(this);}
  );
}

mixin FolderIconMixin on IContentProvider{

  IconData get icon => 
    content.isEmpty? Icons.folder_open: Icons.folder;

  get thumbnail=>Icon(icon);

}

class RectIconButton extends StatelessWidget{

  final IconData icon;
  final Function()? onPressed;
  final Color? iconColor;

  RectIconButton({
    Key? key,
    required this.icon,
    required this.onPressed,
    this.iconColor,
  }):super(key: key);

  Widget build(ctx){
    return SizedTextButton(
      width: 30, height: 30,
      child: Icon(icon,size: 20,color: iconColor,),
      onPressed: onPressed,
    );
  }

}

class ShadowScrollable extends StatefulWidget {

  final Axis direction;
  final Widget child;
  final ScrollController? ctrl;
  final double shadowDistance;

  ShadowScrollable({
    Key? key,
    required this.child,
    required this.direction,
    this.ctrl,
    this.shadowDistance = 20,
  }):super(key: key);

  @override
  _ShadowScrollableState createState() => _ShadowScrollableState();
}

class _ShadowScrollableState extends State<ShadowScrollable> {

  ScrollController? ctrl;

  _UpdateCtrl(){
    if(widget.ctrl == null){
      if(ctrl == null){
        ctrl = ScrollController();
        ctrl!.addListener(_Repaint);
      }
      return;
    }

    if(ctrl != widget.ctrl){
      ctrl?.removeListener(_Repaint);
      ctrl = widget.ctrl;
      ctrl!.addListener(_Repaint);
    }
  }

  _Repaint(){
    setState(() {
      
    });
  }

  @override void initState() {
    super.initState();
    _UpdateCtrl();
  }

  @override void didUpdateWidget(ShadowScrollable oldWidget) {
    super.didUpdateWidget(oldWidget);
    _UpdateCtrl();
  }

  @override void dispose() {
    super.dispose();
    ctrl?.removeListener(_Repaint);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder:(ctx, bnd){
        var cst = bnd.copyWith();
        if(widget.direction == Axis.horizontal){
          if(bnd.hasBoundedWidth){
            cst = cst.copyWith(minWidth: bnd.maxWidth);
          }
          cst = cst.copyWith(maxWidth:double.infinity);
        }else{
          if(bnd.hasBoundedHeight){
            cst = cst.copyWith(minHeight: bnd.maxHeight);
          }
          cst = cst.copyWith(maxHeight:double.infinity);
        }
        return ShaderMask(
          shaderCallback: (bounds){
            bool startShd = false;
            bool endShd = false;

            if(ctrl!.hasClients){
              var pos = ctrl!.position;
              if(pos.extentBefore > 0) startShd = true;
              if(pos.extentAfter > 0) endShd = true;
            }
            bool horizontal = widget.direction == Axis.horizontal;
            var len = horizontal?bounds.width:bounds.height;
            var shdLen = min(widget.shadowDistance/len, 0.5);
            var c = Color.fromARGB(255, 255, 255, 255);
            return LinearGradient(
              begin:horizontal?Alignment.centerLeft:Alignment.topCenter,
              end:horizontal?Alignment.centerRight:Alignment.bottomCenter,
              colors: [
                startShd?c.withOpacity(0):c,
                c,
                c,
                endShd?c.withOpacity(0):c,
              ],
              stops: [
                0,shdLen,1-shdLen,1
              ]
            ).createShader(bounds);
          },
          child: SingleChildScrollView(
            controller: ctrl,
            child:ConstrainedBox(
              constraints: cst,
              child:widget.child,
            ),
            scrollDirection: widget.direction,
          ),
        );
      },
    );
  }
}

class PathBar<T> extends StatelessWidget {

  final Iterable<T> segments;
  final Function(T)? onSelect;

  PathBar({
    Key? key,
    required this.segments,
    this.onSelect,
  }):super(key: key);

  Widget _BuildSegButton(T seg){
    return TextButton(
      child: Text(seg.toString()),
      onPressed: (){onSelect?.call(seg);},
    );
  }

  Iterable<Widget> _BuildRow()sync*{
    for(var s in segments){
      if(s != segments.first)
      {
        yield Icon(Icons.arrow_right);
      }
      yield _BuildSegButton(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShadowScrollable(
      direction: Axis.horizontal,
      child: Row(
        children: _BuildRow().toList(),
      ),
    );
  }
}



class GridWrap extends StatelessWidget{

  final List<Widget> children;
  final double minCellWidth;
  final double maxCellWidth;
  final double cellPadding;
  final double runPadding;

  GridWrap({
    Key? key,
    this.children = const [],
    this.minCellWidth = 80,
    this.maxCellWidth = 100,
    this.cellPadding = 10,
    this.runPadding = 10,
  }):
    assert(minCellWidth >= 0),
    assert(minCellWidth < maxCellWidth),
    super(key: key);

  @override build(ctx){
    return LayoutBuilder(
      builder: (ctx, box){
        
        /*  topleft +------+--------------+------+-----
                    | Cell | Cell padding | Cell |
                    +------+--------------+------+--
                    | Run padding
                    +------+-----
                    | Cell |
                    +------+
                    |
         */
        var width = box.maxWidth;
        //Cell count per run
        var cellCnt = max(1,(width + cellPadding) ~/ minCellWidth);
        //Calculated max cell width
        var calcCellWidth = (
          width - (cellCnt - 1) * cellPadding
        ) / cellCnt;

        var cellWidth = min(calcCellWidth, maxCellWidth);
        var paddingWidth = (width - cellWidth* cellCnt) / (cellCnt - 1);

        var runCnt = (children.length / cellCnt).ceil();

        
        _RunBuilder(int start){
          int end = min(children.length, start + cellCnt);
          var ch = children.sublist(start, end);
          var cells = <Widget>[];
          for(int i = 0; i < ch.length; i++)
          {
            if(i > 0)
              cells.add(Container(width: paddingWidth,));
            cells.add(
              ConstrainedBox(
                constraints:BoxConstraints.tightFor(width:cellWidth,),
                child:ch[i]
              )
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: cells,
          );
        }

        var runs = <Widget>[];
        for(int i = 0; i < runCnt; i++)
        {
          if(i > 0)
            runs.add(Container(height: runPadding,));
          runs.add(_RunBuilder(i*cellCnt));
        }

        return ShadowScrollable(
          direction: Axis.vertical,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children:runs
          ),
        );
      }
    );
  }

}


class TreeViewWidget<T extends IContentProvider> extends StatefulWidget {

  final T root;
  final Future<void> Function(_TreeViewWidgetState<T>)? createItem;

  TreeViewWidget({
    Key? key,
    required this.root,
    this.createItem,
  }):super(key: key);

  @override
  _TreeViewWidgetState createState() => _TreeViewWidgetState<T>();
}

class _FilterResultItem<T extends IContentProvider> extends IContent{
  final List<T> path;
  final IContent item;
  _FilterResultItem(this.item, this.path);

  get name => item.name;
  get thumbnail => item.thumbnail;

  get canModify => false;

  @override Rename(name){}

  @override get defaultAction {
    var itemDefault = item.defaultAction;
    return ContentActionDelegate(
        itemDefault?.name??"Goto",
        (state, content) {
          state.SetPath(path);
          itemDefault?.PerformAction(state, item);
        }
    );
  }

  @override toString(){
    var pathStr = path.join('/');
    return pathStr == "" ? item.toString():[pathStr, item].join('/');
  }

  @override CopyTo(where) => item.CopyTo(where);
}

class _FilterResult<T extends IContentProvider> extends IContentProvider{

  @override CopyTo(IContentProvider where) {}
  @override MoveChildTo(IContent which, IContentProvider where) { }
  @override RemoveChild(IContent which) {}
  @override CreateSubProvider(name){}
  @override Rename(String newName) {}

  @override get canModify => false;

  List<_FilterResultItem<T>> _results;
  String _filter;

  @override get content => _results;

  @override get name => "'$_filter'";

  @override get thumbnail => null;

  _FilterResult(this._filter, this._results);

}

List<_FilterResultItem<T>> Search<T extends IContentProvider>(T target, String filter){

  List<T> currPath = [];

  List<_FilterResultItem<T>> _DoSearch(T t){
    var result = <_FilterResultItem<T>>[];
    var rootPath = currPath.join('/');
    var thisPath = rootPath == ""? t.toString():[rootPath, t].join('/');
    if(thisPath.contains(filter))
      result.add(_FilterResultItem(t, List<T>.from(currPath)));
    
    currPath.add(t);
    for(var c in t.content){
      if(c is T) result += _DoSearch(c);
      else{
        var childPath = [rootPath, t, c].join('/');
        if(childPath.contains(filter))
          result.add(_FilterResultItem(c, List<T>.from(currPath)));
      }
    }

    assert(currPath.last == t);
    currPath.removeLast();
    return result;
  }

  return _DoSearch(target);  
}

class _TreeViewWidgetState<T extends IContentProvider> extends State<TreeViewWidget<T>> {

  late List<T> _currPath;

  final _searchCtrl = TextEditingController();
  String get filterString => _searchCtrl.text;

  _FilterResult? filterResult;

  List<IContentProvider> get _displayPath =>
      filterResult != null? [filterResult!]:_currPath;
  IContentProvider get _dispCurrent => _displayPath.last;
  IContentProvider get _dispRoot => _displayPath.first;

  T get current => _currPath.last;
  T get root => _currPath.first;
  List<T> get path => _currPath;

  void ClearFilter(){
    _searchCtrl.text = "";
  }

  void PushPath(T node) {
    if(node == current) return;
    _currPath.add(node);
    setState(() {});
  }

  void SetPath(List<T> path){
    if(path.isEmpty){
      _currPath = [_currPath.first];
    }else{
      assert(path.first == widget.root);
      _currPath = path;
    }
    ClearFilter();
    setState(() {});
  }

  Future<List<_FilterResultItem<T>>> _PerformSearch(node, filter) async{
    return Search(node, filter);
  }

  @override initState(){
    super.initState();
    _currPath = [widget.root];
    _searchCtrl.addListener(() {
      if(filterString == ""){
        if(filterResult != null){
          filterResult = null;
          setState(() {});
        }
        return;
      }

      _PerformSearch(_currPath.first, filterString).then((r){
        if(!mounted) return;
        filterResult = _FilterResult<T>(filterString, r);
        setState((){});
      });

    });
  }

  @override didUpdateWidget(oldWidget){
    super.didUpdateWidget(oldWidget);
    if(widget.root != root){
      _currPath = [widget.root];
    }
  }

  @override dispose(){
    super.dispose();
    _currPath.clear();
    _searchCtrl.dispose();
  }

  _RenameNode(IContent node)async{
    var name = await RequestTextInput(context, "Rename $node", initialText: node.name);
    if(name == null) return;
    node.Rename(name);
    setState(() {});
  }

  _RemoveNode(IContent node)async{
    var result = await showDialog(
      useRootNavigator: false,
      context: context, builder: (ctx)=>AlertDialog(
        title: Text("Delete $node"),
        content:Text("Are you sure to delete $node?"),
        actions: [
          TextButton(
            child: Text("OK"),
            onPressed: (){
              Navigator.of(ctx).pop(true);
            },
          ),
          TextButton(
            child: Text("Cancel"),
            onPressed: (){
              Navigator.of(ctx).pop(false);
            },
          ),
        ],
      )
    );
    if(!result) return;
    current.RemoveChild(node);
    setState(() {});
  }

  _BuildEntry(IContent node){
    //Build action list
    var actions = <PopupMenuEntry<ContentAction>>[];
    _AppendActionGroup(Iterable<ContentAction> group){
      if(group.isEmpty) return;
      if(actions.isNotEmpty) actions.add(PopupMenuDivider());
      for(var a in group){
        actions.add(PopupMenuItem(
          child: Text(a.name),
          value: a,
        ),);
      }
    }
    _AppendActionGroup(node.customActions);
    _AppendActionGroup([
      if(_dispCurrent.canModify&&node.canModify)
        ContentActionDelegate("Cut",(ctx,cnt){
          tool = _FilePasteTool<T>(this, item: node, from: _dispCurrent, isCut: true);
        }),
      ContentActionDelegate("Copy",(ctx,cnt){
        tool = _FilePasteTool<T>(this, item: node, from: _dispCurrent, isCut: false);
      }),
      if(_dispCurrent.canModify&&node.canModify)
        ContentActionDelegate("Rename",(ctx,cnt){ctx._RenameNode(node);}),
    ]);
    _AppendActionGroup([
      if(_dispCurrent.canModify&&node.canModify)
        ContentActionDelegate("Delete",(ctx,cnt){ctx._RemoveNode(node);}),
    ]);

    return Container(
      child: PopupMenuContainer<ContentAction>(
        items: actions,
        onItemSelected: (s){
          if(s == null) return;
          s.PerformAction(this, node);
        },
        child: TextButton(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child:node.thumbnail??Icon(Icons.file_present),
              ),
              Text(
                node.toString(),
                //overflow: TextOverflow.fade,
                //maxLines: 2,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          onPressed: (){
            node.defaultAction?.PerformAction(this, node);
          },
        ),
      ),
    );
  }

  
  int Function(IContent, IContent) _sorter = _AlphaUpSort;
  get sorter => _sorter;
  set sorter(fn){
    if(_sorter!= fn){
      _sorter = fn;
      setState((){});
    }
  }

  static int _AlphaUpSort(IContent a, IContent b){
    if(a is IContentProvider && b is! IContentProvider) return 1;
    return a.name.compareTo(b.name);
  }
  static int _AlphaDownSort(IContent a, IContent b){
    if(b is IContentProvider && a is! IContentProvider) return 1;
    return b.name.compareTo(a.name);
  }

  List<IContent> _SortChildren(Iterable<IContent> children){
    var s = List<IContent>.from(children);
    s.sort(sorter);
    return s;
  }

  Widget? _tool;
  Widget? get tool => _tool;
  set tool(Widget? val){
    if(_tool != val){
      _tool = val;
      setState((){});
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PathBar<IContentProvider>(
          segments: _displayPath,
          onSelect: (n){
            if(n == _currPath.last) return;
            for(int i = _currPath.length - 1; i > 0; i--){
              if(_currPath.last != n){
                _currPath.removeLast();
              }
            }
            setState((){});
          },
        ),
        InputBox(
          ctrl: _searchCtrl,
        ),
        Row(
          children: [
            RectIconButton(icon: Icons.sort_by_alpha, onPressed: (){
              if(sorter != _AlphaUpSort){
                sorter = _AlphaUpSort;
              }else{
                sorter = _AlphaDownSort;
              }
            }),
            Expanded(
              child:_tool??_ItemCreateTool(this),
            ),
          ],
        ),

        Divider(
          height: 2,
          thickness: 2,
        ),

        Expanded(
          child: GridWrap(
            children:[
              for(var c in _SortChildren(_dispCurrent.content))
                _BuildEntry(c),
            ],
          ),
        ),
        
      ],
    );
  }

}

class _ItemCreateTool<T extends IContentProvider> extends StatelessWidget {

  _TreeViewWidgetState<T> state;

  _ItemCreateTool(this.state);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        RectIconButton(
          icon: Icons.create_new_folder,
          onPressed: !state.current.canModify?
            null:(){_NewFolder(context);}
        ),
        if(state.widget.createItem!=null)
          RectIconButton(
            icon: Icons.note_add,
            onPressed: 
              (!state.current.canModify)?
              null:_NewItem
          ),
      ],
    );
  }

  void _NewFolder(BuildContext ctx)async{
    var ctrl = TextEditingController();
    String? name = await RequestTextInput(ctx, "New Folder", hint:"Enter name...");
    if(name == null) return;
    state.current.CreateSubProvider(name);
    state.setState(() {});
  }

  void _NewItem()async{
    await state.widget.createItem!(state);
    state.setState(() {});
  }
}

class _FilePasteTool<T extends IContentProvider> extends StatelessWidget {
  _TreeViewWidgetState<T> state;

  IContentProvider from;
  IContent item;
  bool isCut;

  _FilePasteTool(this.state,
    {required this.item, required this.from, required this.isCut}
  );

  @override
  Widget build(BuildContext context) {
    String hint = "${isCut?'Move':'Copy'} $item to here";
    return Row(
      children: [
        Expanded(
          child: ShadowScrollable(
            direction: Axis.horizontal,
            child: Text(hint, textAlign: TextAlign.end,),
          ),
        ),
        RectIconButton(
          icon: Icons.check,
          iconColor: !state.current.canModify?null:Colors.green,
          onPressed: !state.current.canModify?
            null:_PasteItem,
        ),
        RectIconButton(
          icon: Icons.close,
          iconColor: Colors.red,
          onPressed: _Cancel
        ),
      ],
    );
  }

  void _PasteItem()async{
    if(isCut){
      from.MoveChildTo(item, state.current);
    }else{
      item.CopyTo(state.current);
    }
    state.tool = null;
  }

  void _Cancel()async{
    state.tool = null;
  }
}
