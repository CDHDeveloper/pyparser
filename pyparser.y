/*
TODO: - не обрабатывать параметры - хранить полную строку
      - по поводу полиморфизма узнать
*/

%{
    #include <string>
    #include <iostream>

    using namespace std;
    #define DEBUG
    #define YYSTYPE string

    string className  = "";
    string funcName   = "";
    string funcParams = "";
    
    int yylex(void);
    void yyerror(const char *str) {
        printf("%s\n", str);
    }
    int main();
%}

%token CLASS DEFINED COLON DOT LBRACE RBRACE ID OTHER DEF COMMA EQUAL

%%
input: /* empty */
     | input class_def
     | input func_def
     | input other_token
;

/* CLASS */
class_def: CLASS classname inheritance COLON suite
    {
        #ifdef DEBUG
            cout << "Class: " << className << endl;
        #endif
    }
;
classname: ID
            {
                className = $1;
            }
;
inheritance: /* empty */
           | LBRACE class_args_list RBRACE
;
class_args_list: /* empty */
               | class_arg
;
class_arg: ID
            {
                #ifdef DEBUG
                    cout << "Class: "      << className 
                         << ": child to: " << $1 << endl;
                #endif
            }
          | class_arg COMMA
          | class_arg ID
           {
                #ifdef DEBUG
                    cout << "Class: "      << className 
                         << ": child to: " << $2 << endl;
                #endif
           }
;
/* end of CLASS */

/* FUNCTION */
func_def: DEF funcname parameters COLON suite
    {
        #ifdef DEBUG
            cout << "Function: " << funcName
                 << "(" << funcParams << ")" << endl;
        #endif
        funcParams = "";
    }
;
funcname: ID
          {
              funcName = $1;
          }
;
parameters: LBRACE func_args_list RBRACE
;
func_args_list: /* empty */
                {
                    funcParams = "";
                }
              | func_arg
                {
                    funcParams = $1;
                }
;
func_arg: ID
        | sublist
        | func_arg COMMA
        | func_arg ID
        | func_arg EQUAL OTHER
        | func_arg sublist
;
sublist: LBRACE func_arg RBRACE
;
/* end of FUNCTION */

suite:
;

other_token: DEFINED
           | COLON
           | DOT
           | ID
           | OTHER
           | COMMA
           | EQUAL
           | LBRACE
           | RBRACE
;
%%

int main()
{
    return yyparse();
}