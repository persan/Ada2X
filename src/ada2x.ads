------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                     Copyright (C) 2003-2014, AdaCore                     --
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

with Asis;
with interfaces.c;
package Ada2X is

   Version : constant String := "0.0.0";

   Fatal_Error     : exception;
   --  Raised when a non-recoverable error has been found

   Parameter_Error : exception;
   --  Raised if ada2wsdl received a wrong option/parameter

   Spec_Error      : exception;
   --  Raised if ada2wsdl has found a problem while parsing the Ada spec

   function Location (E : Asis.Element) return String;
   --  Returns E's location in the form <line>:<column>

   procedure Raise_Spec_Error
     (E       : Asis.Element;
      Message : String) with No_Return;
   --  Raises Spec_Error exception with the given message. Add a source
   --  location information for entity E.

   type Unsigned_Long is mod 2 ** 64;
   type Unsigned_Int is mod 2 ** 32;
   type Unsigned_Short is mod 2 ** 16;
   type Unsigned_Byte is mod 2 ** 8;

   subtype Byte is Short_Short_Integer;
   subtype Short is Interfaces.C.Short;

end Ada2X;
