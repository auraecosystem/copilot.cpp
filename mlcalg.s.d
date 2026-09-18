// D language example demonstrating ranges and lambdas
import std.stdio;
import std.algorithm;
import std.array;

void main() {
    int[] numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    
    // Filter even numbers and square them
    auto results = numbers
        .filter!(n => n % 2 == 0)
        .map!(n => n * n)
        .array;
        
    writeln("Processed results: ", results);
}
