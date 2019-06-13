// Section: String Operations
//-----------------------------------------------------------------------------
// Function: substr()
// Usage:
//   substr(str, [pos], [len])
// Description:
//   Returns a substring from a string start at position `pos` with length `len`, or 
//   if `len` isn't given, the rest of the string.  
// Arguments:
//   str = string to operate on
//   pos = starting index of substring, or vector of first and last position.  Default: 0
//   len = length of substring, or omit it to get the rest of the string.  If len is less than zero the emptry string is returned.  
// Example:
//   substr("abcdefg",3,3);     // Returns "def"
//   substr("abcdefg",2);       // Returns "cdefg"
//   substr("abcdefg",len=3);   // Returns "abc"
//   substr("abcdefg",[2,4]);   // Returns "cde"
//   substr("abcdefg",len=-2)); // Returns ""
function substr(str, pos=0, len=undef, substr="") =
        is_list(pos) ? substr(str, pos[0], pos[1]-pos[0]+1) :
        len <= 0 || pos>=len(str) ? substr :
        len == undef ? substr(str, pos, len(str)-pos, substr) :
        substr(str, pos+1, len-1, str(substr, str[pos]));

// Function suffix()
// Usage:
//   suffix(str,len)
// Description:
//   Returns the last `len` characters from the input string
function suffix(str,len) = substr(str, len(str)-len,len);


// Function: str_join()
// Usage:
//   str_join(list, [sep])
// Description:
//   Returns the concatenation of a list of strings, optionally with a
//   separator string inserted between each string on the list.
// Arguments:
//   list = list of strings to concatenate
//   sep = separator string to insert.  Default: ""
// Example:
//   str_join(["abc","def","ghi"]);        // Returns "abcdefghi"
//   str_join(["abc","def","ghi"], " + ");  // Returns "abc + def + ghi"
function str_join(list,sep="",_i=0, _result="") =
    _i >= len(list)-1 ? (_i==len(list) ? _result : str(_result,list[_i])) :
      str_join(list,sep,_i+1,str(_result,list[_i],sep));

// Function: downcase()
// Usage:
//   downcase(str)
// Description:
//   Returns the string with the standard ASCII upper case letters A-Z replaced
//   by their lower case versions.
// Arguments:
//   str = string to convert
// Example:
//   downcase("ABCdef");   // Returns "abcdef"
function downcase(str) =
   str_join([for(char=str) let(code=ord(char)) code>=65 && code<=90 ? chr(code+32) : char]);

// Function: str_int()
// Usage:
//   str_int(str, [base])
// Description:
//   Converts a string into an integer with any base up to 16.  Returns NaN if 
//   conversion fails.  Digits above 9 are represented using letters A-F in either
//   upper case or lower case.  
// Arguments:
//   str = string to convert
//   base = base for conversion, from 2-16.  Default: 10
// Example:
//   str_int("349");        // Returns 349
//   str_int("-37");        // Returns -37
//   str_int("+97");        // Returns 97
//   str_int("43.9");       // Returns nan
//   str_int("1011010",2);  // Returns 90
//   str_int("13",2);       // Returns nan
//   str_int("dead",16);    // Returns 57005
//   str_int("CEDE", 16);   // Returns 52958
//   str_int("");           // Returns 0
function str_int(str,base=10) =
    str==undef ? undef :
    len(str)==0 ? 0 : 
    let(str=downcase(str))
    str[0] == "-" ? -_str_int_recurse(substr(str,1),base,len(str)-2) :
    str[0] == "+" ?  _str_int_recurse(substr(str,1),base,len(str)-2) :
    _str_int_recurse(str,base,len(str)-1);

function _str_int_recurse(str,base,i) =
    let( digit = search(str[i],"0123456789abcdef"),
         last_digit = digit == [] || digit[0] >= base ? (0/0) : digit[0])
    i==0 ? last_digit : 
        _str_int_recurse(str,base,i-1)*base + last_digit;

// Function: str_float()
// Usage:
//   str_float(str)
// Description:
//   Converts a string to a floating point number.  Returns NaN if the
//   conversion fails.
// Arguments:
//   str = string to convert
// Example:
//   str_float("44");       // Returns 44
//   str_float("3.4");      // Returns 3.4
//   str_float("-99.3332"); // Returns -99.3332
//   str_float("3.483e2");  // Returns 348.3
//   str_float("-44.9E2");  // Returns -4490
//   str_float("7.342e-4"); // Returns 0.0007342
//   str_float("");         // Returns 0
function str_float(str) =
     str==undef ? undef :
     len(str) == 0 ? 0 :
     in_list(str[1], ["+","-"]) ? (0/0) : // Don't allow --3, or +-3
     str[0]=="-" ? -str_float(substr(str,1)) :
     str[0]=="+" ?  str_float(substr(str,1)) :
     let(esplit = str_split(str,"eE") )
     len(esplit)==2 ? str_float(esplit[0]) * pow(10,str_int(esplit[1])) :
     let( dsplit = str_split(str,["."]))
     str_int(dsplit[0])+str_int(dsplit[1])/pow(10,len(dsplit[1]));

// Function: str_frac()
// Usage:
//   str_frac(str)
// Description:
//   Converts a string fraction, two integers separated by a "/" character, to a floating point number.
// Arguments:
//   str = string to convert
// Example:
//   str_frac("3/4");     // Returns 0.75
//   str_frac("-77/9");   // Returns -8.55556
//   str_frac("+1/3");    // Returns 0.33333
//   str_frac("19");      // Returns 19
//   str_frac("");        // Returns 0
//   str_frac("3/0");     // Returns inf
//   str_frac("0/0");     // Returns nan
function str_frac(str) =
    str == undef ? undef :
    let( num = str_split(str,"/"))
    len(num)==1 ? str_int(num[0]) :
    len(num)==2 ? str_int(num[0])/str_int(num[1]) :
    (0/0);

// Function: str_num()
// Usage:
//   str_num(str)
// Description:
//   Converts a string to a number.  The string can be either a fraction (two integers separated by a "/") or a floating point number.
//   Returns NaN if the conversion fails.
// Example:
//   str_num("3/4");    // Returns 0.75
//   str_num("3.4e-2"); // Returns 0.034
function str_num(str) =
    str == undef ? undef :
    let( val = str_frac(str) )
    val == val ? val :
    str_float(str);


// Function: str_split()
// Usage:
//   str_split(str, sep, [keep_nulls])
// Description:
//   Breaks an input string into substrings using a separator or list of separators.  If keep_nulls is true
//   then two sequential separator characters produce an empty string in the output list.  If keep_nulls is false
//   then no empty strings are included in the output list.
//
//   If sep is a single string then each character in sep is treated as a delimiting character and the input string is
//   split at every delimiting character.  Empty strings can occur whenever two delimiting characters are sequential.
//   If sep is a list of strings then the input string is split sequentially using each string from the list in order. 
//   If keep_nulls is true then the output will have length equal to `len(sep)+1`, possibly with trailing null strings
//   if the string runs out before the separator list.  
// Arguments
//   str = string to split
//   sep = a string or list of strings to use for the separator
//   keep_nulls = boolean value indicating whether to keep null strings in the output list.  Default: true
// Example:
//   str_split("abc+def-qrs*iop","*-+");     // Returns ["abc", "def", "qrs", "iop"]
//   str_split("abc+*def---qrs**iop+","*-+");// Returns ["abc", "", "def", "", "", "qrs", "", "iop", ""]
//   str_split("abc      def"," ");          // Returns ["abc", "", "", "", "", "", "def"]
//   str_split("abc      def"," ",keep_nulls=false);  // Returns ["abc", "def"]
//   str_split("abc+def-qrs*iop",["+","-","*"]);     // Returns ["abc", "def", "qrs", "iop"]
//   str_split("abc+def-qrs*iop",["-","+","*"]);     // Returns ["abc+def", "qrs*iop", "", ""]
function str_split(str,sep,keep_nulls=true) =
   !keep_nulls ? _remove_empty_strs(str_split(str,sep,keep_nulls=true)) :
   is_list(sep) ? str_split_recurse(str,sep,i=0,result=[]) :
   let( cutpts = concat([-1],sort(flatten(search(sep, str,0))),[len(str)]))
   [for(i=[0:len(cutpts)-2]) substr(str,cutpts[i]+1,cutpts[i+1]-cutpts[i]-1)];

function str_split_recurse(str,sep,i,result) =
   i == len(sep) ? concat(result,[str]) :
    let( pos = search(sep[i], str),
         end = pos==[] ? len(str) : pos[0]
      )
    str_split_recurse(substr(str,end+1), sep, i+1,
                    concat(result, [substr(str,0,end)]));
                    
function _remove_empty_strs(list) =
    list_remove(list, search([""], list,0)[0]);
