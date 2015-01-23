with Ada.Strings.Maps;
package Ada2X.Utils is
   use Ada;
   Spaces : constant Strings.Maps.Character_Set :=
              Strings.Maps.To_Set (' ' & ASCII.HT & ASCII.LF & ASCII.CR);
   --  Set of spaces to ignore during parsing


   function Image (Str : Wide_String) return String;
   --  Return Str as a lower-case and trimmed string

   function Image (Str : Integer) return String;

end Ada2X.Utils;
