
enum OpCode{
    NOP, //No operation
    HLT, //Halt the interpreter
    RET, //Return from function, pop frame from call stack

//Call:
//  [object model]
    callstatic, //<libName | typeName , funcName>  3 call method statically
    callmem,    //<libName | typeName | funcName>  2 call method using vtable
//  [base]
    call,       //(closure) 1 call closure
    ldfn,       //<libName | typeName | funcName>(object)->closure 2 load method from vtable and current object
    ldstaticfn, //<libName | typeName , funcName>->closure         3 load method statically(static env)


//NewObject:
//  [object model]
    newobj,     //<libName | typeName>->object 2
////obj (type) -> object
    copy,       //(object)->object             1
//ldnull->object

//Type manipulation
//  [object model]
////ldtype (object) -> type
    cast,       //<libName | typeName>(object)->object 2 cast object to type, if can't, return null with casted type
////cast (type object) -> object
    typecmp,    //<libName | typeName>(object)->u32  2 compare type using the inheritance chain
    isnull,     //(obj) null: (reftype, obj == nullptr) or (type == nullptr) 1

    PUSH,// <u32>     2 push N null value onto stack
    PUSHIMM,// #val32  2 load 1 int32 immediate value onto stack
    POP, //            1 Pop one element out of stack
    POPI,// <u32>     2 Pop n elements out of stack
//Transfer
//  [object model]
    ldmem, //<libName | typeName | fieldName>(src)->object 2  load member var onto stack
    stmem, // <libName | typeName | fieldName>(dst, object) 2 store to member var
    ldstatic, // <libName | typeName , fieldName>->object 3 load from static fields
    ststatic, // <libName | typeName , fieldName>(object) 3 store to static fields
//  [base]
    ldarg, // <u32>->object   2  load from frame bottom + u32
    starg, // <u32>(object)   2  store to frame bottom + u32
    ldi, // <u32>->object     2  load from stack top - u32
    sti, // <u32>(object)     2  store to stack top - u32

    ldthis, // ()->(object)  1  load this env onto stack

    ldloc, //(u32)->object  1   same as ldarg
    stloc, //(u32, object)  1   same as starg
    ld, //(u32)->object     1   ...ldi
    st, //(u32, object)     1   ...sti

    JUMP,
    JMPI,

//  1    2
    JZ,  JZI, //  *: (addr, cond) Jump to addr if cond == 0
    JNZ, JNZI, // *I: <i32>(cond)  Jump to addr if cond != 0
    
    JB,  JBI,
    JNB, JNBI,
    
    JA,  JAI,
    JNA, JNAI,


//Compiler directives:
    d_embed, //<fnName> directly embed native functions into program.
}

final int Count = OpCode.JNAI.index + 1;
