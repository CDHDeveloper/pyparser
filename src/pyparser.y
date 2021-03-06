%{
///////////////////////////////////////////////////////////////////////////////
// This file is the part of SourceAnalyzer source codes.                     //
// SourceAnalyzer is a program that search out a call-graph of               //
// given source code. See <http://trac-hg.assembla.com/SourceAnalyzer>       //
// Copyright (C) 2008-2009 SourceAnalyzer contributors                       //
//                                                                           //
// This program is free software: you can redistribute it and/or modify      //
// it under the terms of the GNU General Public License as published by      //
// the Free Software Foundation, either version 3 of the License,            //
// any later version.                                                        //
//                                                                           //
// This program is distributed in the hope that it will be useful,           //
// but WITHOUT ANY WARRANTY; without even the implied warranty of            //
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             //
// GNU General Public License for more details.                              //
//                                                                           //
// You should have received a copy of the GNU General Public License         //
// along with this program.  If not, see <http://www.gnu.org/licenses/>.     //
///////////////////////////////////////////////////////////////////////////////

    #define DEBUG
    #include <cstdio>
    #include <string>
    #include <iostream>
    #include <stack>

    //#include "callgraph.h"
    
    using namespace std;
    #define YYSTYPE string
    #define YYERROR_VERBOSE 1
    
    typedef pair <string, int> meta_data;
    typedef stack <meta_data> meta_stack;

    static meta_stack class_st;
    static meta_stack func_st;
    static string func_name = "";
    static string call_params = "";
    static string file_name = "";

    // remove all instructions (meta data -> string) from stack 
    // with largest indent than current instruction has
    static void clean_stack( meta_stack& stack, int indent );

    int  wrapRet = 1;
    
    int yylex(void);
    extern "C" {
        int yywrap( void ) {
            return wrapRet;
        }
    }
    void yyerror(const char *str) {
        //#ifdef DEBUG
          //  DEBUGMSG( line << ": SA Python Parser: " << str );
        //#endif
    }    
    extern FILE* yyin;   

    static const string type = "undefined";
    static bool isInteractive;
    //CallGraph* callGraph;
    int main();

%}

%token CLASS DEFINED COLON DOT LBRACE RBRACE ID OTHER DEF COMMA STAR MESSAGE
%start input

%left RBRACE
%left LBRACE

%%
input: /* empty */
     | input class_def
     | input func_def
     | input calls_chain
     | input error
;

/* CLASS */
class_def: CLASS classname inheritance COLON suite
    {
        int indent = @1.last_column;
        meta_data new_class($2, indent);

        clean_stack( class_st, indent );
        class_st.push( new_class );

        #ifdef DEBUG
            cout //<< "[" << indent << "] "  
                 << @$.first_line
                 << " >> CLASS: " 
                 << $2            << "("
                 << $3            << ")"
                 << endl;
        #endif
    }
;
classname: ID
           {
               $$ = $1;
           }
;
inheritance: /* empty */
             {
                 $$ = "";
             }
           | LBRACE class_args_list RBRACE
             {
                 $$ = $2;
             }
;
class_args_list: /* empty */
                 {
                     $$ = "";
                 }
               | class_arg
                 {
                     $$ = $1;
                 }
;
class_arg: dotted_name
         | class_arg COMMA dotted_name
           {
               $$ += $2 + $3;
           }
;
/* end of CLASS */

/* FUNCTION */
func_def: DEF funcname LBRACE func_args_list RBRACE COLON suite
          {
              string fnc_name = $2;
              int indent = @1.last_column;
              
              clean_stack( class_st, indent );
              meta_stack tmp_class_st(class_st);

              while (!tmp_class_st.empty())
              {
                  fnc_name = tmp_class_st.top().first + "." + fnc_name;
                  tmp_class_st.pop();
              }

              // replace fnc_name for $2 for less information 
              //   about function location
              meta_data new_func(fnc_name, indent);
              clean_stack( func_st, indent );
              func_st.push( new_func );

              #ifdef DEBUG
                  cout //<< "[" << indent << "] " 
                       << @$.first_line << " >> FUNC:  " 
                       << fnc_name      << "("
                       << $4            << ")"
                       << endl;
              #endif

             //callGraph->addDefinition( fnc_name, $4, type, @$.first_line, file_name );
             //callGraph->addImplementation( fnc_name, $4, type, @$.first_line, file_name );

          }
;
funcname: ID
          {
              $$ = $1;
          }
;
func_args_list: /* empty */
                {
                    $$ = "";
                }
              | func_arg
                {
                    $$ = $1;
                }
;
func_arg: dotted_name
        | star_arg
        | func_arg OTHER
          {
              $$ += $2;
          }
        | func_arg COMMA
          {
              $$ += $2;
          }
        | func_arg dotted_name
          {
              $$ += $2;
          }
        | func_arg star_arg
          {
              $$ += $2;
          }
        | func_arg MESSAGE
          {
              $$ += $2;
          }
;
star_arg: STAR ID
          {
              $$ = $1 + $2;
          }
        | STAR STAR ID
          {
              $$ = $1 + $2 + $3;
          }
;
/* end of FUNCTION */

suite:
;

/* FUNCTION CALL */
calls_chain: func_call
             {
                #ifdef DEBUG
                     cout //<< "[" << @$.last_column << "] " 
                          << @$.first_line
                          << " Function: " << func_name 
                          << " >> CALL: "  << $$
                          << " >> PARAM: " << call_params << endl;
                #endif
                //callGraph->addCall( func_name, $$, call_params, @$.first_line, file_name );
             }
           | calls_chain DOT func_call
             {
                 $$ += $2 + $3;
                #ifdef DEBUG
                     cout //<< "[" << @$.last_column << "] " 
                          << @$.first_line 
                          << " Function: " << func_name 
                          << " >> CALL: "  << $$
                          << " >> PARAM: " << call_params << endl;                     
                #endif
                //callGraph->addCall( func_name, $$, call_params, @$.first_line, file_name );
             }
;
func_call: dotted_name func_call_params
           {
              bool isFirst = true;

              func_name = "";
              // if func_call_params are in more than 1 line
              //   then indent can be unexpected
              //   but @1 determines it correctly
              int indent = @1.last_column;

              clean_stack( func_st, indent );
              meta_stack tmp_func_st(func_st);

              while (!tmp_func_st.empty())
              {
                  if(isFirst)
                  {
                      func_name = tmp_func_st.top().first;
                      tmp_func_st.pop();
                      isFirst = false;
                      continue;
                  }
                  func_name = tmp_func_st.top().first + "." + func_name;
                  tmp_func_st.pop();
              }

              $$ = $1 + $2;
           }
;
dotted_name: ID
           | dotted_name DOT ID
             {
                 $$ += $2 + $3;
             }
;
func_call_params: LBRACE RBRACE
                  {
                      call_params = "";
                      $$ = $1 + $2;
                  }
                | LBRACE call_params RBRACE
                  {
                      call_params = $2;
                      $$ = $1 + $2 + $3;
                  }
;
call_params: OTHER
           | DEFINED
           | MESSAGE
           | dotted_name
           | STAR
           | calls_chain
           | func_call_params
           | call_params DEFINED
             {
                 $$ += $2;
             }
           | call_params MESSAGE
             {
                 $$ += $2;
             }
           | call_params dotted_name
             {
                 $$ += $2;
             }
           | call_params OTHER
             {
                 $$ += $2;
             }
           | call_params calls_chain
             {
                 $$ += $2;
             }
           | call_params COMMA
             {
                 $$ += $2;
             }
           | call_params COLON
             {
                 $$ += $2;
             }
           | call_params STAR
             {
                 $$ += $2;
             }
           | call_params func_call_params
             {
                 $$ += $2;
             }
;
/* end of FUNCTION CALL */
/*
other_token: dotted_name
           | DEFINED
           | COLON
           | DOT
           | OTHER
           | COMMA
           | STAR
           | MESSAGE
           | LBRACE
           | RBRACE
;*/
%%

static void clean_stack( meta_stack& stack, int indent )
{
    while(!stack.empty())
    {
        if( indent > stack.top().second )
            break;
        stack.pop();
    }
}

/*int parse( CallGraph& callGraphObj, bool isInter = false, const string fileName = "" ) {
    int returnCode = 0;
    
    isInteractive = isInter;

    if( true == isInter ) {
        wrapRet = 0;
    }
    else {
        wrapRet = 1;
    }

    if( fileName == "" ) {
        file_name = "unknown";
        yyin = stdin;
        callGraph = &callGraphObj;
        returnCode = yyparse();
    }
    else {
        file_name = fileName;
        FILE* file;
        file = fopen( fileName.c_str(), "r" );
        yyin = file;
        callGraph = &callGraphObj;
        returnCode = yyparse();
        fclose( yyin );
    }
    return returnCode;
}*/
int main()
{
    return yyparse();
}