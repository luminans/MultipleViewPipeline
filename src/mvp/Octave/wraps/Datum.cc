#include <mvp/Octave/MvpWrapper.h>
#include <vw/Cartography/Datum.h>

BEGIN_MVP_WRAPPER(Datum, vw::cartography::Datum)
  MVP_WRAP_CONSTRUCTOR((std::string))
  MVP_WRAP(semi_major_axis)
  MVP_WRAP(semi_minor_axis)
END_MVP_WRAPPER()