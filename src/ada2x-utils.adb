with Ada.Characters.Conversions;
with Ada.Characters.Handling;
with Ada.Strings.Fixed;
package body Ada2X.Utils is
   -----------
   -- Image --
   -----------

   function Image (Str : Wide_String) return String is
   begin
      return Characters.Handling.To_Lower
        (Strings.Fixed.Trim
           (Characters.Conversions.To_String (Str), Strings.Both));
   end Image;

   function Image (Str : Integer) return String is
   begin
      return Strings.Fixed.Trim (Str'Img, Strings.Both);
   end Image;

end Ada2X.Utils;
