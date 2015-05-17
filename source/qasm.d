module qasm;

import std.stdio;
import std.string;
import std.conv;
import std.array;
import std.container.array;
import qlib.util;
import qlib.asm_tokens;
import qlib.instruction;
import qlib.collections;
import qlib.qbin;


/**
 * Parse the instruction lexemes passed and produce an instruction
 * as defined in qlib
 *
 * Params:
 *      instruction = The lexemes to be parsed
 *      map = The map that maintains the relation between the identifiers 
 *              and their indices
 *
 * Returns:
 *      An instruction that can be executed by the qvm
 */
Instruction parseInstruction(InstructionLexeme instruction, IdentifierMap* map) {
    int c = ' ';
    int i = 0;
    string[] args = instruction.args;
    Instruction ins = Instruction(Opcode.NULL, 0, 0, 0, 0, instruction.line);
    ins.opcode = instruction.opcode;
    auto argTypes = argLocations[ins.opcode];
    if(args.length == 1 && ins.opcode == Opcode.QUBIT) {
        map.addIndex(args[0], IdentifierType.QUBIT);
        int index = map.indexOf(args[0]);
        return Instruction(Opcode.QUBIT, index, 0, 0, 0, instruction.line);
    }
    foreach(int idx, string arg; args) {
        int iarg = map.indexOf(arg);
        if(iarg == -1) {
            map.addIndex(arg, IdentifierType.QUBIT);
            iarg = map.indexOf(arg);
        }
        switch(argTypes[idx]) {
            case(InstructionArgType.QUBIT):
                ins.qubit = iarg;
                break;

            case (InstructionArgType.OP1):
                ins.op1 = iarg;
                break;

            case (InstructionArgType.OP2):
                ins.op2 = iarg;
                break;

            case (InstructionArgType.NUMBER):
                ins.number = iarg;
                break;

            default:
                break;
        }
    }
    return ins;

}

unittest {
    import std.stdio;
    writeln("Dub Test For Assembler");
    IdentifierMap m = IdentifierMap();
    m.addIndex("X", IdentifierType.FUNCTION);
    m.addIndex("I", IdentifierType.FUNCTION);
    auto ins = InstructionLexeme(35, Opcode.QUBIT, ["a"]);
    auto ret = parseInstruction(ins, &m);
    assert(ret.qubit == 3);
    assert(ret.lineNumber == 35);
    ins = InstructionLexeme(130, Opcode.IF, ["a", "X"]);
    ret = parseInstruction(ins, &m);
    assert(ret.qubit == 3);
    assert(ret.op1 == 1);
    ins = InstructionLexeme(130, Opcode.IFELSE, ["a", "X", "I"]);
    ret = parseInstruction(ins, &m);
    assert(ret.qubit == 3);
    assert(ret.op1 == 1);
    assert(ret.op2 == 2);
    ret = parseInstruction(InstructionLexeme(140, Opcode.SREC, ["4"]), &m);

}

/**
 * A container that keeps track of which scope we're
 * working in, in order to place the instructions into
 * the proper functions in the output.
 */
struct QasmState {
    int line = 0;
    Function* current;
    FunctionList fnList;
    IdentifierMap map;

    /**
     * Adds the function to the state.
     */
    int addFunction(string name) {
        map.addIndex(name, IdentifierType.FUNCTION);
        fnList[map.indexOf(name)] = Function(map.indexOf(name));
        return map.indexOf(name);

    }
    
    /**
     * Switches the current function to the specified index
     */
    void switchFunction(int index) {
        current = &(fnList[index]);
    }

    /**
     * Adds the instruction specified to the current function 
     */
    void addInstruction(InstructionLexeme instruction) {
        Instruction ins = parseInstruction(instruction, &map);
        current.instructions.insert(ins);
    }

    /**
     * Creates a Program from the instructions we have parsed
     * so far.
     *
     * Returns:
     *      A program the VM can execute based on all the
     *      lines processed so far.
     */
    Program createProgram() {
        return new Program(fnList, map);
    }
}

unittest {
    auto state = QasmState();
    writeln(state.addFunction("haha"));
    writeln(state.addFunction("lala"));
    state.switchFunction(1);
    auto ins = InstructionLexeme(35, Opcode.QUBIT, ["a"]);
    state.addInstruction(ins);
    writeln(state.current.instructions[]);

}

/**
 * A line in an assembly file can either
 * be a function header which declares the start
 * of a user defined function, an instruction or
 * an end function which declares the end of the user
 * defined function
 */
enum LineType {
    NULL,
    FUNCTION_HEADER,
    INSTRUCTION,
    END_FUNCTION
}

/**
 * The lexemes of an instruction
 */
struct InstructionLexeme {
    int line;
    Opcode opcode;
    string[] args;
}

/**
 * A line can be either instruction related
 * or function related.
 */
union LineInfo {
    InstructionLexeme instruction;
    string functionName;
}


/**
 * A line in an assembly file. A line has a number, type
 * and associated information depending on the line.
 */
struct Line {
    int number;
    LineInfo info;
    LineType type;
}

/**
 * Returns a line, it's type and the parameters
 * of the line if any.
 */
Line lexLine(string s, int ln) {
    if(s.strip().length == 0) {
        return Line();
    }
    string[] params = s.strip().split(" ");
    string test = params[0].toUpper();
    Line line;
    line.number = ln;
    Opcode op = to_opcode(test);
    if(op != Opcode.NULL) {
        line.type = LineType.INSTRUCTION;
        line.info.instruction.opcode = op;
    }else if(test == "FN") {
        line.type = LineType.FUNCTION_HEADER;
    }else if(test == "ENDFN") {
        line.type = LineType.END_FUNCTION;
    }else{
        throw new Exception("Syntax error:" ~to!string(ln)~" unknown instruction "~test);
    }

    auto qi = &(line.info.instruction);
    switch(line.type) {
        case LineType.INSTRUCTION:
            qi.args = new string[3];
            qi.line = ln;
            for(int i = 1; i <= 3; i++) {
                if(i < params.length) {
                    qi.args[i-1] = params[i];
                }else{
                    qi.args[i-1] = "";
                }
            }
            break;
        case LineType.FUNCTION_HEADER:
            line.info.functionName = params[1];
            break;
        default:
            break;
    }
    return line;
}

unittest {
    writeln(lexLine("qubit a", 36));
    writeln(lexLine("fn myOp", 30));
    writeln(lexLine("endfn", 20));
    writeln(lexLine("fcnot 2", 60));
}

/**
 * Creates a map containing the list of predefined operators
 */ 
IdentifierMap createMap() {
    IdentifierMap map;
    map.addIndex("H", IdentifierType.FUNCTION);
    map.addIndex("CNOT", IdentifierType.FUNCTION);
    return map;
}

import std.array;

Program processQasm(string code) {
    QasmState state;
    state.map = createMap();
    int mainIndex = state.addFunction("main");
    state.switchFunction(mainIndex);
    int lineNumber = 1;
    foreach(string ln; code.split("\n")) {
        Line line = lexLine(ln, lineNumber);
        switch(line.type) {
            case LineType.NULL:
                break;
            case LineType.INSTRUCTION:
                state.addInstruction(line.info.instruction);
                break;
            case LineType.FUNCTION_HEADER:
                int index = state.addFunction(line.info.functionName);
                state.switchFunction(index);
                break;
            case LineType.END_FUNCTION:
                state.switchFunction(mainIndex);
                break;
            default:
                throw new Exception("Invalid line type");
        }
        lineNumber++;
    }
    return state.createProgram();
}


Program loadQasm(string path) {
    QasmState state;
    state.map = createMap();
    int mainIndex = state.addFunction("main");
    state.switchFunction(mainIndex);
    File f = File(path, "r");
    int lineNumber = 1;
    while(!f.eof) {
        string ln = strip(f.readln());
        Line line = lexLine(ln, lineNumber);
        switch(line.type) {
            case LineType.NULL:
                break;
            case LineType.INSTRUCTION:
                state.addInstruction(line.info.instruction);
                break;
            case LineType.FUNCTION_HEADER:
                int index = state.addFunction(line.info.functionName);
                state.switchFunction(index);
                break;
            case LineType.END_FUNCTION:
                state.switchFunction(mainIndex);
                break;
            default:
                throw new Exception("Invalid line type");
        }
        lineNumber++;
    }
    return state.createProgram();
}

unittest {
    File f = File("/tmp/qasm_test_1.qasm", "w");
    f.writeln("qubit x");
    f.writeln("qubit y");
    f.writeln("fn bellStates");
    f.writeln("    load x");
    f.writeln("    load y");
    f.writeln("    on x");
    f.writeln("    apply H");
    f.writeln("    on y");
    f.writeln("    apply H");
    f.writeln("    on x");
    f.writeln("    on y");
    f.writeln("    apply CNOT");
    f.writeln("endfn");
    f.writeln("on x");
    f.writeln("on y");
    f.writeln("apply bellStates");
    f.writeln("measure x");
    f.writeln("measure y");
    f.flush();
    f.close();
    auto p = loadQasm("/tmp/qasm_test_1.qasm");
    writeln("LAMFKNFF");
    writeln(p.map);
    writeln(p.functions);
    p.save("/tmp/out.qbin");
    Program q = new Program();
    q.loadFromFile("/tmp/out.qbin");
}
