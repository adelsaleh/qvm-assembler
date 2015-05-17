import qasm;
import std.stdio;
import qlib.collections;
import std.array;

void main(string[] args) {
    if(args.length != 2) {
        writeln("Usage: qvm-assmbler qbin_file_path");
        return;
    }
    Program p = loadQasm(args[1]);
    p.save(args[1].split(".")[0] ~ ".qbin");
}
