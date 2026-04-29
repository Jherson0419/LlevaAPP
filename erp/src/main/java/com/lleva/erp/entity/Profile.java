package com.lleva.erp.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Perfil de aplicación (cliente / conductor), tabla {@code profiles}.
 * URLs de documentos alineadas con la app móvil (Supabase Storage).
 */
@Entity
@Table(name = "profiles")
public class Profile {

    @Id
    @Column(name = "id", nullable = false, columnDefinition = "uuid")
    private UUID id;

    @Column(name = "phone", nullable = false, length = 32)
    private String phone;

    @Column(name = "role", nullable = false, length = 32)
    private String role;

    @Column(name = "full_name", nullable = false, columnDefinition = "text")
    private String fullName;

    @Column(name = "email", columnDefinition = "text")
    private String email;

    @Column(name = "dni", length = 32)
    private String dni;

    @Column(name = "car_plate", length = 32)
    private String carPlate;

    @Column(name = "car_brand", columnDefinition = "text")
    private String carBrand;

    @Column(name = "car_model", columnDefinition = "text")
    private String carModel;

    @Column(name = "is_approved", nullable = false)
    private Boolean isApproved = Boolean.FALSE;

    @Column(name = "is_banned", nullable = false)
    private Boolean isBanned = Boolean.FALSE;

    @Column(name = "car_year")
    private Integer carYear;

    @Column(name = "car_color", length = 64)
    private String carColor;

    @Column(name = "soat_expiration")
    private OffsetDateTime soatExpiration;

    @Column(name = "property_card_expiration")
    private OffsetDateTime propertyCardExpiration;

    @Column(name = "technical_review_expiration")
    private OffsetDateTime technicalReviewExpiration;

    @Column(name = "license_category", length = 32)
    private String licenseCategory;

    @Column(name = "license_number", length = 64)
    private String licenseNumber;

    @Column(name = "birth_date")
    private OffsetDateTime birthDate;

    @Column(name = "driver_rating", precision = 4, scale = 2)
    private BigDecimal driverRating;

    @Column(name = "dni_front_url", columnDefinition = "text")
    private String dniFrontUrl;

    @Column(name = "dni_back_url", columnDefinition = "text")
    private String dniBackUrl;

    @Column(name = "license_url", columnDefinition = "text")
    private String licenseUrl;

    @Column(name = "soat_url", columnDefinition = "text")
    private String soatUrl;

    @Column(name = "property_card_url", columnDefinition = "text")
    private String propertyCardUrl;

    @Column(name = "profile_pic_url", columnDefinition = "text")
    private String profilePicUrl;

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public String getPhone() {
        return phone;
    }

    public void setPhone(String phone) {
        this.phone = phone;
    }

    public String getRole() {
        return role;
    }

    public void setRole(String role) {
        this.role = role;
    }

    public String getFullName() {
        return fullName;
    }

    public void setFullName(String fullName) {
        this.fullName = fullName;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getDni() {
        return dni;
    }

    public void setDni(String dni) {
        this.dni = dni;
    }

    public String getCarPlate() {
        return carPlate;
    }

    public void setCarPlate(String carPlate) {
        this.carPlate = carPlate;
    }

    public String getCarBrand() {
        return carBrand;
    }

    public void setCarBrand(String carBrand) {
        this.carBrand = carBrand;
    }

    public String getCarModel() {
        return carModel;
    }

    public void setCarModel(String carModel) {
        this.carModel = carModel;
    }

    public Boolean getIsApproved() {
        return isApproved;
    }

    public void setIsApproved(Boolean approved) {
        isApproved = approved;
    }

    public Boolean getIsBanned() {
        return isBanned;
    }

    public void setIsBanned(Boolean banned) {
        isBanned = banned;
    }

    public Integer getCarYear() {
        return carYear;
    }

    public void setCarYear(Integer carYear) {
        this.carYear = carYear;
    }

    public String getCarColor() {
        return carColor;
    }

    public void setCarColor(String carColor) {
        this.carColor = carColor;
    }

    public OffsetDateTime getSoatExpiration() {
        return soatExpiration;
    }

    public void setSoatExpiration(OffsetDateTime soatExpiration) {
        this.soatExpiration = soatExpiration;
    }

    public OffsetDateTime getPropertyCardExpiration() {
        return propertyCardExpiration;
    }

    public void setPropertyCardExpiration(OffsetDateTime propertyCardExpiration) {
        this.propertyCardExpiration = propertyCardExpiration;
    }

    public OffsetDateTime getTechnicalReviewExpiration() {
        return technicalReviewExpiration;
    }

    public void setTechnicalReviewExpiration(OffsetDateTime technicalReviewExpiration) {
        this.technicalReviewExpiration = technicalReviewExpiration;
    }

    public String getLicenseCategory() {
        return licenseCategory;
    }

    public void setLicenseCategory(String licenseCategory) {
        this.licenseCategory = licenseCategory;
    }

    public String getLicenseNumber() {
        return licenseNumber;
    }

    public void setLicenseNumber(String licenseNumber) {
        this.licenseNumber = licenseNumber;
    }

    public OffsetDateTime getBirthDate() {
        return birthDate;
    }

    public void setBirthDate(OffsetDateTime birthDate) {
        this.birthDate = birthDate;
    }

    public BigDecimal getDriverRating() {
        return driverRating;
    }

    public void setDriverRating(BigDecimal driverRating) {
        this.driverRating = driverRating;
    }

    public String getDniFrontUrl() {
        return dniFrontUrl;
    }

    public void setDniFrontUrl(String dniFrontUrl) {
        this.dniFrontUrl = dniFrontUrl;
    }

    public String getDniBackUrl() {
        return dniBackUrl;
    }

    public void setDniBackUrl(String dniBackUrl) {
        this.dniBackUrl = dniBackUrl;
    }

    public String getLicenseUrl() {
        return licenseUrl;
    }

    public void setLicenseUrl(String licenseUrl) {
        this.licenseUrl = licenseUrl;
    }

    public String getSoatUrl() {
        return soatUrl;
    }

    public void setSoatUrl(String soatUrl) {
        this.soatUrl = soatUrl;
    }

    public String getPropertyCardUrl() {
        return propertyCardUrl;
    }

    public void setPropertyCardUrl(String propertyCardUrl) {
        this.propertyCardUrl = propertyCardUrl;
    }

    public String getProfilePicUrl() {
        return profilePicUrl;
    }

    public void setProfilePicUrl(String profilePicUrl) {
        this.profilePicUrl = profilePicUrl;
    }
}
