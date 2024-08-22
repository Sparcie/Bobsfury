
{conditional defines for determining hardware
 support for the current build }

{$define general}  { conditional define for general exe}

{$ifdef XT}        {build for an XT only}
{$undef general}
{$define CGA}
{$define noAdlib}
{$define XTKbd}
{$endif}

{$ifdef EDITOR}
{$undef general}
{$define VGA}
{$define VESA}
{$define noAdlib}
{$endif}


{$ifdef general}
{$define CGA}
{$define EGA}
{$define VGA}
{$define VESA}
{$define pitdbl}
{$endif}
