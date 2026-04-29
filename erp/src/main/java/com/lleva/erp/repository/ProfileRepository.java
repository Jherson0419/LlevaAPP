package com.lleva.erp.repository;

import com.lleva.erp.entity.Profile;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface ProfileRepository extends JpaRepository<Profile, UUID> {

    List<Profile> findByRoleAndIsApproved(String role, Boolean isApproved);
}
