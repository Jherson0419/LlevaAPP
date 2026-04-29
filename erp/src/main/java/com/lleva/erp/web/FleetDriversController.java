package com.lleva.erp.web;

import com.lleva.erp.entity.Profile;
import com.lleva.erp.repository.ProfileRepository;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import java.util.UUID;

/**
 * Flota y conductores — integrar con su seguridad ({@code @PreAuthorize}, etc.).
 */
@Controller
@RequestMapping("/fleet")
public class FleetDriversController {

    private final ProfileRepository profileRepository;

    public FleetDriversController(ProfileRepository profileRepository) {
        this.profileRepository = profileRepository;
    }

    @GetMapping("/drivers")
    public String drivers(Model model) {
        model.addAttribute("pendingDrivers",
                profileRepository.findByRoleAndIsApproved("driver", Boolean.FALSE));
        return "fleet/drivers";
    }

    @PostMapping("/drivers/{id}/approve")
    public String approveDriver(
            @PathVariable UUID id,
            RedirectAttributes redirectAttributes) {
        Profile p = profileRepository.findById(id).orElse(null);
        if (p == null || !"driver".equalsIgnoreCase(p.getRole())) {
            redirectAttributes.addFlashAttribute("error", "Conductor no encontrado.");
            return "redirect:/fleet/drivers";
        }
        p.setIsApproved(Boolean.TRUE);
        profileRepository.save(p);
        redirectAttributes.addFlashAttribute("message", "Conductor aprobado correctamente.");
        return "redirect:/fleet/drivers";
    }
}
