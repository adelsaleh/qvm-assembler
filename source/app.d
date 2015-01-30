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


Instruction parseInstruction(QasmInstruction instruction, IdentifierMap* map) {
    int c = ' ';
    int i = 0;
    string[] args = instruction.args;
    Instruction ins = Instruction(Opcode.NULL, 0, 0, 0, 0, instruction.line);
    ins.opcode = instruction.opcode;
    auto argTypes = argLocations[ins.opcode];
    if(args.length == 1 && ins.opcode == Opcode.QUBIT) {
        map.addIndex(args[0], IdentifierType.QUBIT);
        int index = map.indexOf(args[0]);
        return Instruction(Opcode.QUBIT, index, 0, 0, 0);
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

struct QasmState {
    int line = 0;
    Function* current;
    FunctionList fnList;
    IdentifierMap map;

    int addFunction(string name) {
        /**
         * Adds the function to the state.
         */
        map.addIndex(name, IdentifierType.FUNCTION);
        return map.indexOf(name);

    }
    
    void switchFunction(int index) {
        /**
         * Switches the current function to the specified index
         */
        current = &(fnList[index]);
    }
    void addInstruction(QasmInstruction instruction) {
        /**
         * Adds the instruction specified 
         */
         Instruction ins = parseInstruction(instruction, &map);
         current.instructions.insert(ins);
    }

    Program createProgram() {
        return new Program(fnList, map);
    }
}

enum LineType {
    FUNCTION_HEADER,
    INSTRUCTION,
    END_FUNCTION
}

struct QasmInstruction {
    int line;
    Opcode opcode;
    string[] args;
}

union LineInfo {
    QasmInstruction instruction;
    string functionName;
}

struct Line {
    int number;
    LineInfo info;
    LineType type;
}

Line parseLine(string s, int ln) {
    /**
     * Returns a line, it's type and the parameters
     * of the line if any.
     */
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

Program loadQasm(string path) {
    QasmState state;
    int mainIndex = state.addFunction("main");
    state.switchFunction(mainIndex);
    File f = File(path, "r");
    int lineNumber = 1;
    while(!f.eof) {
        string ln = strip(f.readln());
        Line line = parseLine(ln, lineNumber);
        switch(line.type) {
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
                break;
        }
        lineNumber++;
    }
    return state.createProgram();
}

void main(string[] args) {
    Program p = loadQasm(args[1]);
    p.save(args[1].split(".")[0] ~ ".qbin");
}
