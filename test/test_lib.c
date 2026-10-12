int add_ints(int a, int b) {
    return a + b;
}

double mul_doubles(double a, double b) {
    return a * b;
}

int str_len(const char* s) {
    int len = 0;
    while (s[len]) len++;
    return len;
}

long long triple(int x) {
    return (long long)x * 3;
}

int global_counter = 100;