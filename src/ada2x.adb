------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                     Copyright (C) 2003-2013, AdaCore                     --
--                                                                          --
--  This is free software;  you can redistribute it  and/or modify it       --
--  under terms of the  GNU General Public License as published  by the     --
--  Free Software  Foundation;  either version 3,  or (at your option) any  --
--  later version.  This software is distributed in the hope  that it will  --
--  be useful, but WITHOUT ANY WARRANTY;  without even the implied warranty --
--  of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU     --
--  General Public License for  more details.                               --
--                                                                          --
--  You should have  received  a copy of the GNU General  Public  License   --
--  distributed  with  this  software;   see  file COPYING3.  If not, go    --
--  to http://www.gnu.org/licenses for a complete copy of the license.      --
------------------------------------------------------------------------------

with Ada.Exceptions;

with Asis.Declarations;
with Asis.Elements;
with Asis.Text;
with Ada2X.Utils;

package body Ada2X is

   use Ada;
   use Asis;

   --------------
   -- Location --
   --------------

   function Location (E : Asis.Element) return String is


      E_Span    : constant Text.Span := Text.Element_Span (E);
      Unit      : constant Asis.Declaration :=
                    Elements.Unit_Declaration
                      (Elements.Enclosing_Compilation_Unit (E));
      --  Unit containing element E

      Unit_Name : constant Asis.Element := Declarations.Names (Unit) (1);
      --  Unit name
   begin
      return Utils.Image (Text.Element_Image (Unit_Name)) & ".ads:"
        & Utils.Image (E_Span.First_Line)
        & ':' & Utils.Image (E_Span.First_Column);
   end Location;

   ----------------------
   -- Raise_Spec_Error --
   ----------------------

   procedure Raise_Spec_Error
     (E       : Asis.Element;
      Message : String) is
   begin
      Exceptions.Raise_Exception
        (Spec_Error'Identity, Location (E) & ": " & Message);
   end Raise_Spec_Error;

end Ada2X;
