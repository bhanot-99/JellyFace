#include "borderconfig.hpp"

#include <algorithm>

namespace jellyface::config {

int BorderConfig::minThickness() {
    return 2;
}

int BorderConfig::clampedThickness() const {
    return std::max(minThickness(), m_thickness);
}

} // namespace jellyface::config
