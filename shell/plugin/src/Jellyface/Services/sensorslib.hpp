#pragma once

#include <optional>

namespace jellyface::services::sensorslib {

void ensureInit();

[[nodiscard]] std::optional<double> cpuPackageTemp();
[[nodiscard]] std::optional<double> gpuPciAverageTemp();

} // namespace jellyface::services::sensorslib
