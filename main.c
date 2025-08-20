#include <stdio.h>

extern int my_printf(const char *, ...);  

int main() 
{
    int a = 0;
    printf ("---------------------------------------\n");
    my_printf ("%o\n%d %s %x %n%d%%%c%b\n%d %s %x %d%%%c%b\n", 
              -1, -1, "love", 3802, &a, 100, 33, 127,
              -1, "love", 3802, 100, 33, 127);
    my_printf ("a = %d\n", a);
    printf ("---------------------------------------\n");

    a = 0;
    printf ("%o\n%d %s %x %n%d%%%c%b\n%d %s %x %d%%%c%b\n", 
            -1, -1, "love", 3802, &a, 100, 33, 127,
            -1, "love", 3802, 100, 33, 127);
    printf ("a = %d\n", a);
    printf ("---------------------------------------\n");
    
    int n = 0;
    my_printf ("%p\n", &n);
    printf ("---------------------------------------\n");
    printf ("%p\n", &n);
    printf ("---------------------------------------\n");

    return 0;
}