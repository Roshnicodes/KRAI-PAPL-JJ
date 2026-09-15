const closeOpenChipMultiControls = (event) => {
  const eventPath = typeof event.composedPath === "function" ? event.composedPath() : [];
  document.querySelectorAll(".chip-multi-control.open").forEach((control) => {
    const clickedInside = eventPath.includes(control) || control.contains(event.target);
    if (!clickedInside) control.classList.remove("open");
  });
};

const closeMobileMenuOnEscape = (event) => {
  if (event.key !== "Escape") return;

  document.body.classList.remove("mobile-menu-open");
  document.querySelector("[data-mobile-menu-toggle]")?.setAttribute("aria-expanded", "false");
};

if (!window.__vrpLayoutGlobalsReady) {
  window.__vrpLayoutGlobalsReady = true;
  document.addEventListener("keydown", closeMobileMenuOnEscape);
  document.addEventListener("click", closeOpenChipMultiControls);
  document.addEventListener("click", (event) => {
    document.querySelectorAll("[data-dashboard-activity-picker][open]").forEach((picker) => {
      if (!picker.contains(event.target)) picker.removeAttribute("open");
    });
  });
}

const vrpUiLabel = "Jeevika Jankar";
const replaceVrpUiText = (value) => `${value || ""}`
  .replace(/\bactivities\b/gi, "Major Work Indicators")
  .replace(/\bactivity\b/gi, "Major Work Indicator")
  .replace(/\bvrp\b/gi, vrpUiLabel)
  .replace(/वीआरपी/g, vrpUiLabel)
  .replace(/व्हीआरपी/g, vrpUiLabel)
  .replace(/ଭିଆରପି/g, vrpUiLabel);

const fetchJson = async (url, params = {}) => {
  const requestUrl = new URL(url, window.location.origin);
  if (params && typeof params === "object") {
    Object.entries(params).forEach(([key, value]) => {
      if (value !== undefined && value !== null && value !== "") {
        requestUrl.searchParams.set(key, value);
      }
    });
  }

  const response = await fetch(requestUrl, { headers: { Accept: "application/json" } });
  if (!response.ok) throw new Error("Request failed");
  return response.json();
};

const initAflFarmerMapping = () => {
  document.querySelectorAll("[data-afl-farmer-mapping]").forEach((form) => {
    if (form.dataset.aflFarmerMappingReady === "true") return;

    const farmerSelect = form.querySelector("[data-afl-farmer-select]");
    if (!farmerSelect) return;

    const mappedField = (name) => form.querySelector(`[data-afl-mapped-field='${name}']`);
    const applySelectedFarmer = () => {
      const option = farmerSelect.selectedOptions[0];
      const values = {
        farm_id: option?.dataset.aflFarmId || "",
        ics_name: option?.dataset.aflIcsName || "",
        tracenet_no: option?.dataset.aflTracenetNo || "",
        crop_year: option?.dataset.aflCropYear || "",
        aadhar_number: option?.dataset.aflAadharNumber || ""
      };

      Object.entries(values).forEach(([name, value]) => {
        const field = mappedField(name);
        if (field) field.value = value;
      });
    };

    farmerSelect.addEventListener("change", applySelectedFarmer);
    if (form.dataset.aflNewRecord === "true" && farmerSelect.value) applySelectedFarmer();
    form.dataset.aflFarmerMappingReady = "true";
  });
};

const initFastNavigation = () => {
  const path = window.location.pathname;
  document.querySelectorAll(".side-nav a[href]").forEach((link) => {
    const href = link.getAttribute("href");
    if (!href || href.startsWith("http")) return;

    const active = path === href || (href.length > 1 && path.startsWith(href));
    link.classList.toggle("active", active);
  });

  document.querySelectorAll(".side-module").forEach((module) => {
    if (module.querySelector(".side-sub-link.active")) module.setAttribute("open", "");
  });

  const mobileMenuToggle = document.querySelector("[data-mobile-menu-toggle]");
  const mobileSidebar = document.querySelector("[data-mobile-sidebar]");
  const mobileSidebarBackdrop = document.querySelector("[data-mobile-sidebar-backdrop]");
  const setMobileMenuOpen = (isOpen) => {
    document.body.classList.toggle("mobile-menu-open", isOpen);
    mobileMenuToggle?.setAttribute("aria-expanded", isOpen ? "true" : "false");
  };

  if (mobileMenuToggle && mobileMenuToggle.dataset.bound !== "true") {
    mobileMenuToggle.dataset.bound = "true";
    mobileMenuToggle.addEventListener("click", () => {
      setMobileMenuOpen(!document.body.classList.contains("mobile-menu-open"));
    });
  }

  if (mobileSidebarBackdrop && mobileSidebarBackdrop.dataset.bound !== "true") {
    mobileSidebarBackdrop.dataset.bound = "true";
    mobileSidebarBackdrop.addEventListener("click", () => setMobileMenuOpen(false));
  }

  mobileSidebar?.querySelectorAll("a").forEach((link) => {
    if (link.dataset.mobileSidebarBound === "true") return;

    link.dataset.mobileSidebarBound = "true";
    link.addEventListener("click", () => setMobileMenuOpen(false));
  });

  document.querySelectorAll(".side-module").forEach((module) => {
    if (module.dataset.sideModuleBound === "true") return;

    module.dataset.sideModuleBound = "true";
    module.addEventListener("toggle", () => {
      if (!module.open) return;

      document.querySelectorAll(".side-module[open]").forEach((openModule) => {
        if (openModule !== module) openModule.removeAttribute("open");
      });
    });
  });
};

const initPasswordToggles = () => {
  document.querySelectorAll("[data-password-toggle]").forEach((button) => {
    if (button.dataset.passwordToggleBound === "true") return;

    button.dataset.passwordToggleBound = "true";
    button.addEventListener("click", () => {
      const input = button.closest(".password-field, .login-password-field")?.querySelector("[data-password-toggle-input]");
      if (!input) return;

      const showPassword = input.type === "password";
      input.type = showPassword ? "text" : "password";
      button.setAttribute("aria-label", showPassword ? "Hide password" : "Show password");
      button.title = showPassword ? "Hide password" : "Show password";
      button.classList.toggle("is-visible", showPassword);
    });
  });
};

const runDeferredLayoutInit = () => {
  if (!window.__layoutVisitId) return;
  initDeferredLayoutPage();
};

const scheduleDeferredLayoutInit = () => {
  window.__layoutVisitId = (window.__layoutVisitId || 0) + 1;
  const visitId = window.__layoutVisitId;

  if (window.__layoutDeferredIdle) {
    window.cancelIdleCallback?.(window.__layoutDeferredIdle);
    window.__layoutDeferredIdle = null;
  }
  if (window.__layoutDeferredTimer) {
    clearTimeout(window.__layoutDeferredTimer);
    window.__layoutDeferredTimer = null;
  }

  const runIfCurrent = () => {
    if (visitId !== window.__layoutVisitId) return;
    runDeferredLayoutInit();
  };

  if (document.querySelector("[data-target-mapping]")) {
    runIfCurrent();
  } else if (window.requestIdleCallback) {
    window.__layoutDeferredIdle = window.requestIdleCallback(runIfCurrent, { timeout: 400 });
  } else {
    window.__layoutDeferredTimer = setTimeout(runIfCurrent, 32);
  }
};

document.addEventListener("turbo:click", () => {
  window.__layoutVisitId = (window.__layoutVisitId || 0) + 1;
});

function initDeferredLayoutPage() {
  // Card detail popup: a small trigger box opens that card's detail inside a modal dialog.
  const cardPopup = document.querySelector("[data-card-popup]");
  if (cardPopup && cardPopup.dataset.cardPopupBound !== "true") {
    cardPopup.dataset.cardPopupBound = "true";
    const popupTitle = cardPopup.querySelector("[data-card-popup-title]");
    const popupBody = cardPopup.querySelector("[data-card-popup-body]");
    const closeCardPopup = () => {
      if (typeof cardPopup.close === "function") cardPopup.close();
      else cardPopup.removeAttribute("open");
    };

    document.querySelectorAll("[data-card-popup-trigger]").forEach((trigger) => {
      if (trigger.dataset.cardPopupTriggerBound === "true") return;
      trigger.dataset.cardPopupTriggerBound = "true";
      trigger.addEventListener("click", () => {
        const card = trigger.closest(".metric-card-group");
        if (!card) return;
        const title = card.querySelector(".metric-card-group-title");
        const titleText = title ? title.textContent.trim() : "";
        const detail = card.querySelector(".cc-jj-status-groups, .metric-card-group-items");
        if (popupTitle) popupTitle.textContent = titleText;
        if (popupBody) {
          popupBody.innerHTML = "";
          if (detail) popupBody.appendChild(detail.cloneNode(true));
          // FCO-wise JJ Requirement: 3 boxes per row so Sausar is row 1 and Turekela is row 2.
          const grid = popupBody.querySelector(".metric-card-group-items");
          if (grid) grid.style.gridTemplateColumns = `repeat(${/requirement/i.test(titleText) ? 3 : 2}, minmax(0, 1fr))`;
        }
        if (typeof cardPopup.showModal === "function") cardPopup.showModal();
        else cardPopup.setAttribute("open", "");
      });
    });

    cardPopup.querySelectorAll("[data-card-popup-close]").forEach((btn) => btn.addEventListener("click", closeCardPopup));
    cardPopup.addEventListener("click", (event) => {
      if (event.target === cardPopup) closeCardPopup();
    });
  }

  document.querySelectorAll("[data-participation-filter-form]").forEach((form) => {
    if (form.dataset.participationFilterBound === "true") return;

    form.dataset.participationFilterBound = "true";
    const vrpSelect = form.querySelector("select[name='vrp_id']");
    const fcocSelect = form.querySelector("select[name='fcocs[]']");
    const farmerSelect = form.querySelector("select[name='farmer_ids[]']");
    const monthSelect = form.querySelector("select[name='month']");
    let vrpFcocMap = {};
    let farmerFilterMap = {};
    try {
      vrpFcocMap = JSON.parse(form.dataset.vrpFcocMap || "{}");
    } catch (_error) {
      vrpFcocMap = {};
    }
    try {
      farmerFilterMap = JSON.parse(form.dataset.farmerFilterMap || "{}");
    } catch (_error) {
      farmerFilterMap = {};
    }

    const syncParticipationVrps = () => {
      if (!vrpSelect || !fcocSelect) return;

      const selectedFcocs = Array.from(fcocSelect.selectedOptions || [])
        .map((option) => option.value)
        .filter(Boolean);

      Array.from(vrpSelect.options).forEach((option) => {
        if (!option.value) {
          option.hidden = false;
          option.disabled = false;
          return;
        }

        const compatibleFcocs = vrpFcocMap[option.value] || [];
        const visible = !selectedFcocs.length || compatibleFcocs.some((fcoc) => selectedFcocs.includes(fcoc));
        option.hidden = !visible;
        option.disabled = !visible;
      });

      if (vrpSelect.selectedOptions[0]?.disabled) vrpSelect.value = "";
    };

    const syncParticipationFarmers = () => {
      if (!farmerSelect) return;

      const selectedMonth = monthSelect?.value || "";
      const selectedFcocs = Array.from(fcocSelect?.selectedOptions || [])
        .map((option) => option.value)
        .filter(Boolean);

      Array.from(farmerSelect.options).forEach((option) => {
        const metadata = farmerFilterMap[option.value] || { months: [], fcocs: [] };
        const monthMatches = !selectedMonth || metadata.months.includes(selectedMonth);
        const fcocMatches = !selectedFcocs.length || metadata.fcocs.some((fcoc) => selectedFcocs.includes(fcoc));
        const visible = monthMatches && fcocMatches;
        option.hidden = !visible;
        option.disabled = !visible;
        if (!visible) option.selected = false;
      });
      farmerSelect.dispatchEvent(new Event("chip:refresh"));
    };

    fcocSelect?.addEventListener("change", () => {
      syncParticipationVrps();
      syncParticipationFarmers();
    });
    fcocSelect?.addEventListener("chip:refresh", syncParticipationVrps);
    monthSelect?.addEventListener("change", syncParticipationFarmers);
    syncParticipationVrps();
    syncParticipationFarmers();
  });

  document.querySelectorAll("[data-saved-target-farmers-open]").forEach((button) => {
    if (button.dataset.savedTargetFarmersBound === "true") return;

    button.dataset.savedTargetFarmersBound = "true";
    button.addEventListener("click", async () => {
      const dialog = document.getElementById(button.dataset.savedTargetFarmersOpen);
      if (!dialog) return;
      if (typeof dialog.showModal === "function") dialog.showModal();
      else dialog.setAttribute("open", "open");
      if (!dialog.dataset.farmersUrl || dialog.dataset.farmersLoaded === "true" || dialog.dataset.farmersLoading === "true") return;
      const list = dialog.querySelector(".target-dialog-farmer-list");
      dialog.dataset.farmersLoading = "true";
      list.textContent = "Loading farmers...";
      try {
        const data = await fetchJson(dialog.dataset.farmersUrl);
        const fragment = document.createDocumentFragment();
        (data.farmers || []).forEach((farmer) => {
          const item = document.createElement("div");
          item.className = "vrp-ics-farmer-item";
          const content = document.createElement("span");
          const name = document.createElement("strong");
          name.textContent = farmer.farmer_name || `Farmer #${farmer.id}`;
          const meta = document.createElement("small");
          meta.textContent = [["Father", farmer.father_name], ["Tracenet", farmer.tracenet_no], ["Mobile", farmer.mobile_no], ["Village", farmer.village_name]]
            .filter(([, value]) => value).map(([label, value]) => `${label}: ${value}`).join(" | ");
          content.append(name, meta);
          item.append(content);
          fragment.append(item);
        });
        list.replaceChildren(fragment);
        if (!list.childElementCount) list.textContent = "No farmers found.";
        dialog.dataset.farmersLoaded = "true";
      } catch (_error) {
        list.textContent = "Could not load farmers. Close and click View to retry.";
      } finally {
        delete dialog.dataset.farmersLoading;
      }
    });
  });

  document.querySelectorAll("[data-saved-target-farmers-dialog]").forEach((dialog) => {
    const closeButton = dialog.querySelector("[data-saved-target-farmers-close]");
    if (!closeButton || closeButton.dataset.savedTargetFarmersBound === "true") return;

    closeButton.dataset.savedTargetFarmersBound = "true";
    closeButton.addEventListener("click", () => {
      if (typeof dialog.close === "function") dialog.close();
      else dialog.removeAttribute("open");
    });
  });

  document.querySelectorAll("[data-ics-exit-form]").forEach((form) => {
    const select = form.querySelector("[data-ics-exit-farmer-select]");
    const fieldFor = (name) => form.querySelector(`[data-ics-exit-field='${name}']`);
    const previewFor = (name) => document.querySelectorAll(`[data-ics-exit-preview='${name}']`);
    const today = new Date().toISOString().slice(0, 10);

    let farmerDetails = {};
    try {
      farmerDetails = JSON.parse(form.dataset.farmerDetails || "{}");
    } catch (_error) {
      farmerDetails = {};
    }

    const setFieldValue = (name, value) => {
      const field = fieldFor(name);
      if (!field) return;

      field.value = value || "";
      field.dispatchEvent(new Event("input", { bubbles: true }));
    };

    const syncPreview = (field) => {
      const name = field.dataset.icsExitField;
      if (!name) return;

      previewFor(name).forEach((preview) => {
        preview.textContent = field.value || "";
      });
    };

    fieldFor("declaration_date") && (fieldFor("declaration_date").value ||= today);

    select?.addEventListener("change", () => {
      const details = farmerDetails[select.value] || {};

      [
        "farm_id",
        "farmer_name",
        "id_number",
        "farmer_address",
        "farmer_contact_no",
        "farmer_village",
        "tracenet_no",
        "ics_name",
        "grower_group_name",
        "certification_status"
      ].forEach((name) => setFieldValue(name, details[name]));
    });

    form.querySelectorAll("[data-ics-exit-field]").forEach((field) => {
      syncPreview(field);
      field.addEventListener("input", () => syncPreview(field));
      field.addEventListener("change", () => syncPreview(field));
    });
  });

  initPasswordToggles();

  const capitalizeFirstLetter = (input) => {
    const value = input.value;
    if (!value) return;

    const capitalized = value.charAt(0).toUpperCase() + value.slice(1);
    if (capitalized === value) return;

    const cursorStart = input.selectionStart;
    const cursorEnd = input.selectionEnd;
    input.value = capitalized;
    input.setSelectionRange(cursorStart, cursorEnd);
  };

  document.querySelectorAll("[data-capitalize-first]").forEach((input) => {
    capitalizeFirstLetter(input);
    input.addEventListener("input", () => capitalizeFirstLetter(input));
    input.form?.addEventListener("submit", () => capitalizeFirstLetter(input));
  });

  document.querySelectorAll("[data-gps-photo-form]").forEach((form) => {
    if (form.dataset.gpsPhotoBound === "true") return;

    form.dataset.gpsPhotoBound = "true";
    if (!navigator.geolocation) return;

    navigator.geolocation.getCurrentPosition((position) => {
      form.querySelector("[data-gps-latitude]").value = position.coords.latitude || "";
      form.querySelector("[data-gps-longitude]").value = position.coords.longitude || "";
      form.querySelector("[data-gps-accuracy]").value = position.coords.accuracy || "";
    });
  });

  const selectAll = document.querySelector("[data-vrp-select-all]");
  if (selectAll) {
    selectAll.addEventListener("change", () => {
      document.querySelectorAll("[data-vrp-row-select]").forEach((checkbox) => {
        checkbox.checked = selectAll.checked;
      });
    });
  }

  const editButton = document.querySelector("[data-vrp-edit-selected]");
  if (editButton) {
    editButton.addEventListener("click", () => {
      const selected = Array.from(document.querySelectorAll("[data-vrp-row-select]:checked"));

      if (selected.length !== 1) {
        window.alert(replaceVrpUiText("Please select one VRP only"));
        return;
      }

      window.location.href = `/vrps/${selected[0].value}/edit`;
    });
  }

  const csrfToken = document.querySelector("meta[name='csrf-token']")?.content;

  document.querySelectorAll("[data-dashboard-training-filter-select]").forEach((select) => {
    if (select.dataset.dashboardTrainingFilterBound === "true") return;

    select.dataset.dashboardTrainingFilterBound = "true";
    select.addEventListener("change", () => {
      const form = select.closest("form");
      if (!form) return;

      if (select.hasAttribute("data-dashboard-training-month-select")) {
        const subActivitySelect = form.querySelector("[data-dashboard-training-sub-activity-select]");
        if (subActivitySelect) subActivitySelect.value = "";
      }

      if (typeof form.requestSubmit === "function") {
        form.requestSubmit();
        return;
      }

      form.submit();
    });
  });

  // Auto-submit dashboard main filters when any dropdown changes
  document.querySelectorAll("[data-dashboard-filter-select]").forEach((select) => {
    if (select.dataset.dashboardFilterBound === "true") return;

    select.dataset.dashboardFilterBound = "true";
    select.addEventListener("change", () => {
      const form = select.closest("form");
      if (!form) return;

      if (typeof form.requestSubmit === "function") {
        form.requestSubmit();
        return;
      }
      form.submit();
    });
  });

  document.querySelectorAll("[data-dashboard-activity-picker]").forEach((picker) => {
    if (picker.dataset.dashboardActivityBound === "true") return;
    picker.dataset.dashboardActivityBound = "true";

    const form = picker.closest("form");
    const input = form?.querySelector("[data-activity-input]");
    const label = picker.querySelector("[data-activity-label]");
    if (!form || !input || !label) return;

    picker.querySelectorAll("[data-activity-value]").forEach((option) => {
      option.addEventListener("click", (event) => {
        event.preventDefault();
        const value = option.getAttribute("data-activity-value") || "";
        input.value = value;
        label.textContent = value || option.textContent.trim() || "All Activities";
        if (!value) label.textContent = "All Activities";
        picker.removeAttribute("open");
        picker.querySelectorAll(".dashboard-activity-option").forEach((btn) => {
          btn.classList.toggle("is-selected", (btn.getAttribute("data-activity-value") || "") === value);
        });

        if (typeof form.requestSubmit === "function") {
          form.requestSubmit();
          return;
        }
        form.submit();
      });
    });

  });

  const trainingDrilldown = document.querySelector("[data-training-participation-drilldown]");
  if (trainingDrilldown) {
    const drilldownTitle = trainingDrilldown.querySelector("[data-training-participation-drilldown-title]");
    const drilldownCount = trainingDrilldown.querySelector("[data-training-participation-drilldown-count]");
    const drilldownList = trainingDrilldown.querySelector("[data-training-participation-drilldown-list]");
    const trainingTriggers = Array.from(document.querySelectorAll("[data-training-participation-trigger]"));

    const statusLabels = {
      green: "Green Farmers",
      yellow: "Yellow Farmers",
      red: "Red Farmers"
    };

    const formatCountLabel = (count) => `${count} farmer${count === 1 ? "" : "s"}`;
    const formatTrainingDate = (value) => {
      const text = `${value || ""}`.trim();
      if (!text) return "-";

      const match = text.match(/^(\d{4})-(\d{2})-(\d{2})/);
      if (!match) return text;

      return `${match[3]}-${match[2]}-${match[1]}`;
    };

    const clearActiveTrainingTrigger = () => {
      trainingTriggers.forEach((button) => {
        button.classList.remove("is-active");
        button.setAttribute("aria-pressed", "false");
      });
    };

    const renderTrainingDetails = (details, status) => {
      const farmers = Array.isArray(details?.[status]) ? details[status] : [];
      if (!drilldownList) return;

      drilldownList.innerHTML = "";

      if (!farmers.length) {
        const row = document.createElement("tr");
        const cell = document.createElement("td");
        cell.colSpan = 7;
        cell.textContent = "No farmers found for this status.";
        row.appendChild(cell);
        drilldownList.appendChild(row);
        return;
      }

      farmers.forEach((farmer) => {
        const row = document.createElement("tr");
        const farmerCell = document.createElement("td");

        const farmerName = document.createElement("div");
        farmerName.textContent = farmer.farmer_name || "-";
        farmerCell.appendChild(farmerName);

        if (farmer.father_name) {
          const fatherName = document.createElement("small");
          fatherName.textContent = `Father: ${farmer.father_name}`;
          farmerCell.appendChild(fatherName);
        }

        [
          farmerCell,
          farmer.ics || "-",
          farmer.village || "-",
          farmer.vrp || "-",
          farmer.attendance_count ?? 0,
          farmer.status_label || statusLabels[status] || status,
          formatTrainingDate(farmer.work_date)
        ].forEach((value, index) => {
          if (index === 0) {
            row.appendChild(value);
            return;
          }

          const cell = document.createElement("td");
          cell.textContent = `${value}`;
          row.appendChild(cell);
        });

        drilldownList.appendChild(row);
      });
    };

    const activateTrainingDrilldown = (button) => {
      let details = {};
      try {
        details = JSON.parse(button.dataset.trainingParticipationDetails || "{}");
      } catch (_error) {
        details = {};
      }

      const status = button.dataset.trainingParticipationStatus || "green";
      const rows = Array.isArray(details[status]) ? details[status] : [];

      clearActiveTrainingTrigger();
      button.classList.add("is-active");
      button.setAttribute("aria-pressed", "true");

      if (drilldownTitle) {
        drilldownTitle.textContent = button.dataset.trainingParticipationTitle || statusLabels[status] || "Farmer Details";
      }

      if (drilldownCount) {
        drilldownCount.textContent = formatCountLabel(rows.length);
      }

      renderTrainingDetails(details, status);
    };

    trainingTriggers.forEach((button) => {
      button.setAttribute("aria-pressed", "false");
      button.addEventListener("click", () => activateTrainingDrilldown(button));
    });
  }

  document.querySelectorAll("[data-training-row-toggle]").forEach((button) => {
    button.addEventListener("click", () => {
      const targetId = button.dataset.trainingRowTarget;
      if (!targetId) return;

      const target = document.getElementById(targetId);
      if (!target) return;

      const isOpen = !target.hasAttribute("hidden");
      document.querySelectorAll("[data-training-row-details]").forEach((detail) => {
        detail.setAttribute("hidden", "");
      });
      document.querySelectorAll("[data-training-row-toggle]").forEach((toggle) => {
        toggle.setAttribute("aria-expanded", "false");
      });

      if (isOpen) {
        target.setAttribute("hidden", "");
        return;
      }

      target.removeAttribute("hidden");
      button.setAttribute("aria-expanded", "true");
    });
  });

  const themeToggle = document.querySelector("[data-theme-toggle]");
  const themeToggleIcon = document.querySelector("[data-theme-toggle-icon]");
  const themeToggleLabel = document.querySelector("[data-theme-toggle-label]");
  const applyTheme = (theme) => {
    const nextTheme = theme === "dark" ? "dark" : "light";
    document.documentElement.dataset.theme = nextTheme;
    localStorage.setItem("vrp_theme", nextTheme);
    if (themeToggleIcon) themeToggleIcon.textContent = nextTheme === "dark" ? "☀" : "☾";
    if (themeToggleLabel) themeToggleLabel.textContent = nextTheme === "dark" ? "Light" : "Dark";
    themeToggle?.setAttribute("aria-label", nextTheme === "dark" ? "Switch to light mode" : "Switch to dark mode");
  };

  applyTheme(localStorage.getItem("vrp_theme") || "light");
  if (themeToggle && themeToggle.dataset.bound !== "true") {
    themeToggle.dataset.bound = "true";
    themeToggle.addEventListener("click", () => {
      applyTheme(document.documentElement.dataset.theme === "dark" ? "light" : "dark");
    });
  }

  const submitPatch = (path) => {
    const form = document.createElement("form");
    form.method = "post";
    form.action = path;

    const methodInput = document.createElement("input");
    methodInput.type = "hidden";
    methodInput.name = "_method";
    methodInput.value = "patch";
    form.appendChild(methodInput);

    if (csrfToken) {
      const tokenInput = document.createElement("input");
      tokenInput.type = "hidden";
      tokenInput.name = "authenticity_token";
      tokenInput.value = csrfToken;
      form.appendChild(tokenInput);
    }

    document.body.appendChild(form);
    form.submit();
  };

  const deleteSelected = async (paths, message) => {
    if (paths.length === 0) {
      window.alert("Please select at least one record");
      return;
    }

    if (!window.confirm(message)) return;

    const responses = await Promise.all(paths.map((path) => {
      return fetch(path, {
        method: "DELETE",
        headers: {
          "X-CSRF-Token": csrfToken,
          "Accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
        }
      });
    }));

    if (responses.some((response) => !response.ok)) {
      window.alert("Some selected record(s) could not be deleted.");
      return;
    }

    window.location.reload();
  };

  const vrpDeleteButton = document.querySelector("[data-vrp-delete-selected]");
  if (vrpDeleteButton) {
    vrpDeleteButton.addEventListener("click", () => {
      const paths = Array.from(document.querySelectorAll("[data-vrp-row-select]:checked"))
        .map((checkbox) => `/vrps/${checkbox.value}`);

      deleteSelected(paths, replaceVrpUiText("Delete selected VRP record(s)?"));
    });
  }

  const vrpSendButton = document.querySelector("[data-vrp-send-selected]");
  if (vrpSendButton) {
    vrpSendButton.addEventListener("click", async () => {
      const selected = Array.from(document.querySelectorAll("[data-vrp-row-select]:checked"));

      if (selected.length === 0) {
        window.alert(replaceVrpUiText("Please select at least one VRP"));
        return;
      }

      const responses = await Promise.all(selected.map((checkbox) => {
        return fetch(`/vrps/${checkbox.value}/send_for_approval`, {
          method: "PATCH",
          headers: {
            "X-CSRF-Token": csrfToken,
            "Accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
          }
        });
      }));

      if (responses.some((response) => !response.ok)) {
        window.alert(replaceVrpUiText("Some selected VRP record(s) could not be sent for approval."));
        return;
      }

      window.location.reload();
    });
  }

  document.querySelectorAll("[data-vrp-active-selected]").forEach((button) => {
    if (button.dataset.vrpActiveBound === "true") return;

    button.dataset.vrpActiveBound = "true";
    button.addEventListener("click", async () => {
      const selected = Array.from(document.querySelectorAll("[data-vrp-row-select]:checked"));
      const active = button.dataset.vrpActiveSelected;

      if (selected.length === 0) {
        window.alert(replaceVrpUiText("Please select at least one VRP"));
        return;
      }

      const response = await fetch("/vrps/bulk_set_active", {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": csrfToken,
          "Accept": "application/json",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          ids: selected.map((checkbox) => checkbox.value),
          active: active
        })
      });

      if (!response.ok) {
        window.alert(replaceVrpUiText("Some selected VRP record(s) could not be updated."));
        return;
      }

      window.location.reload();
    });
  });

  const moduleSelectAll = document.querySelector("[data-module-select-all]");
  if (moduleSelectAll) {
    moduleSelectAll.addEventListener("change", () => {
      document.querySelectorAll("[data-module-row-select]").forEach((checkbox) => {
        checkbox.checked = moduleSelectAll.checked;
      });
    });
  }

  const aflListTable = document.getElementById("afl_list");
  if (aflListTable) {
    const aflSelectAll = aflListTable.querySelector("[data-afl-select-all]");
    const aflDeleteButton = document.querySelector("[data-afl-delete-selected]");
    const aflQueryInput = document.querySelector("[data-table-search='afl_list']");
    const aflRows = () => Array.from(aflListTable.querySelectorAll("[data-afl-row-select]"));
    const aflSelectAllKey = () => `afl-list-select-all:${(aflQueryInput?.value || "").trim().toLowerCase()}`;
    const restoreAflSelection = () => {
      if (!aflSelectAll) return;

      const selectAllEnabled = sessionStorage.getItem(aflSelectAllKey()) === "1";
      aflSelectAll.checked = selectAllEnabled;
      aflSelectAll.indeterminate = false;
      aflRows().forEach((checkbox) => {
        checkbox.checked = selectAllEnabled;
      });
    };
    const clearAflSelectAll = () => {
      sessionStorage.removeItem(aflSelectAllKey());

      if (!aflSelectAll) return;

      aflSelectAll.checked = false;
      aflSelectAll.indeterminate = false;
    };

    restoreAflSelection();

    aflSelectAll?.addEventListener("change", () => {
      if (aflSelectAll.checked) {
        sessionStorage.setItem(aflSelectAllKey(), "1");
      } else {
        clearAflSelectAll();
      }

      aflRows().forEach((checkbox) => {
        checkbox.checked = aflSelectAll.checked;
      });
    });

    aflRows().forEach((checkbox) => {
      checkbox.addEventListener("change", () => {
        if (!checkbox.checked) {
          clearAflSelectAll();
          return;
        }

        const rows = aflRows();
        const checkedCount = rows.filter((row) => row.checked).length;
        if (rows.length > 0 && checkedCount === rows.length) {
          sessionStorage.setItem(aflSelectAllKey(), "1");
          aflSelectAll.checked = true;
          aflSelectAll.indeterminate = false;
        }
      });
    });

    aflDeleteButton?.addEventListener("click", async () => {
      const bulkSelectAll = sessionStorage.getItem(aflSelectAllKey()) === "1";

      if (bulkSelectAll) {
        if (!window.confirm("Delete all selected AFL records across every page?")) return;

        const url = new URL(aflDeleteButton.dataset.aflBulkDestroyUrl, window.location.origin);
        const query = aflQueryInput?.value?.trim();
        if (query) url.searchParams.set("q", query);

        const response = await fetch(url, {
          method: "DELETE",
          headers: {
            "X-CSRF-Token": csrfToken,
            "Accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
          }
        });

        if (!(response.ok || response.redirected)) {
          window.alert("Some selected record(s) could not be deleted.");
          return;
        }

        sessionStorage.removeItem(aflSelectAllKey());
        window.location.reload();
        return;
      }

      const paths = aflRows()
        .filter((checkbox) => checkbox.checked)
        .map((checkbox) => checkbox.value)
        .map((path) => path.replace(/\/edit$/, ""));

      deleteSelected(paths, "Delete selected record(s)?");
    });
  }

  document.querySelectorAll("[data-access-control-row]").forEach((row) => {
    const menuCheckbox = row.querySelector("[data-access-menu-checkbox]");
    const submenuCheckboxes = Array.from(row.querySelectorAll("[data-access-submenu-checkbox]"));
    if (!menuCheckbox || submenuCheckboxes.length === 0) return;

    const syncMenuCheckbox = () => {
      const checkedCount = submenuCheckboxes.filter((checkbox) => checkbox.checked).length;
      menuCheckbox.checked = checkedCount === submenuCheckboxes.length;
      menuCheckbox.indeterminate = checkedCount > 0 && checkedCount < submenuCheckboxes.length;
    };

    menuCheckbox.addEventListener("change", () => {
      submenuCheckboxes.forEach((checkbox) => {
        checkbox.checked = menuCheckbox.checked;
      });
      menuCheckbox.indeterminate = false;
    });

    submenuCheckboxes.forEach((checkbox) => {
      checkbox.addEventListener("change", syncMenuCheckbox);
    });

    syncMenuCheckbox();
  });

  const moduleRowPaths = (checkbox) => {
    if (!checkbox.dataset.moduleRowPaths) return [checkbox.value];

    try {
      const paths = JSON.parse(checkbox.dataset.moduleRowPaths);
      return Array.isArray(paths) && paths.length ? paths : [checkbox.value];
    } catch (_error) {
      return [checkbox.value];
    }
  };

  const moduleEditButton = document.querySelector("[data-module-edit-selected]");
  if (moduleEditButton) {
    moduleEditButton.addEventListener("click", () => {
      const selected = Array.from(document.querySelectorAll("[data-module-row-select]:checked"));

      if (selected.length !== 1) {
        window.alert("Please select one record only");
        return;
      }

      window.location.href = selected[0].value;
    });
  }

  const moduleDeleteButton = document.querySelector("[data-module-delete-selected]");
  if (moduleDeleteButton) {
    moduleDeleteButton.addEventListener("click", () => {
      const paths = Array.from(document.querySelectorAll("[data-module-row-select]:checked"))
        .flatMap((checkbox) => moduleRowPaths(checkbox))
        .map((path) => path.replace(/\/edit$/, ""));

      deleteSelected(paths, "Delete selected record(s)?");
    });
  }

  const selectedBillRows = () => Array.from(document.querySelectorAll("[data-module-row-select]:checked"))
    .filter((checkbox) => checkbox.dataset.billSendPath || checkbox.dataset.billDeletePath);

  const patchBillRows = async (paths, emptyMessage) => {
    if (!paths.length) {
      window.alert(emptyMessage);
      return;
    }

    const responses = await Promise.all(paths.map((path) => fetch(path, {
      method: "PATCH",
      credentials: "same-origin",
      headers: {
        "X-CSRF-Token": csrfToken,
        "Accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
      }
    })));

    if (responses.some((response) => !(response.ok || response.redirected))) {
      window.alert("Some selected bill(s) could not be updated.");
      return;
    }

    window.location.reload();
  };

  document.querySelector("[data-bill-send-selected]")?.addEventListener("click", () => {
    const paths = selectedBillRows().map((checkbox) => checkbox.dataset.billSendPath).filter(Boolean);
    patchBillRows(paths, "Please select at least one bill");
  });

  document.querySelectorAll("[data-bill-state-selected]").forEach((button) => {
    button.addEventListener("click", () => {
      const state = button.dataset.billStateSelected;
      const paths = selectedBillRows()
        .map((checkbox) => state === "Inactive" ? checkbox.dataset.billInactivePath : checkbox.dataset.billActivePath)
        .filter(Boolean);
      patchBillRows(paths, "Please select at least one bill");
    });
  });

  document.querySelector("[data-bill-delete-selected]")?.addEventListener("click", () => {
    const paths = selectedBillRows().map((checkbox) => checkbox.dataset.billDeletePath).filter(Boolean);
    deleteSelected(paths, "Delete selected bill(s)?");
  });

  document.querySelectorAll("[data-module-status-selected]").forEach((button) => {
    button.addEventListener("click", async () => {
      const selected = Array.from(document.querySelectorAll("[data-module-row-select]:checked"));
      const status = button.dataset.moduleStatusSelected;

      if (selected.length === 0) {
        window.alert("Please select at least one record");
        return;
      }

      const paths = selected.flatMap((checkbox) => moduleRowPaths(checkbox));
      const responses = await Promise.all(paths.map((selectedPath) => {
        const path = `${selectedPath.replace(/\/edit$/, "/set_status")}?status=${encodeURIComponent(status)}`;
        return fetch(path, {
          method: "PATCH",
          headers: {
            "X-CSRF-Token": csrfToken,
            "Accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
          }
        });
      }));

      if (responses.some((response) => !response.ok)) {
        window.alert("Some selected record(s) could not be updated.");
        return;
      }

      window.location.reload();
    });
  });

  document.querySelectorAll("[data-user-status-selected]").forEach((button) => {
    button.addEventListener("click", async () => {
      const selected = Array.from(document.querySelectorAll("[data-module-row-select]:checked"));
      const status = button.dataset.userStatusSelected;

      if (selected.length === 0) {
        window.alert("Please select at least one user");
        return;
      }

      await Promise.all(selected.map((checkbox) => {
        const path = `${checkbox.value.replace(/\/edit$/, "/set_status")}?status=${encodeURIComponent(status)}`;
        return fetch(path, {
          method: "PATCH",
          headers: {
            "X-CSRF-Token": csrfToken,
            "Accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
          }
        });
      }));

      window.location.reload();
    });
  });

  const uniquePresent = (values) => Array.from(new Set(values.map((value) => `${value || ""}`.trim()).filter(Boolean)));
  const stripDisplayName = (value) => `${value || ""}`.replace(/\s*\([^)]*\)\s*$/, "").trim();
  const displayNameFromLabel = (value) => {
    const match = `${value || ""}`.match(/\(([^)]*)\)\s*$/);
    return match ? match[1].trim() : "";
  };
  const normalizeOption = (value) => stripDisplayName(value).toLowerCase();
  const optionValue = (option) => (typeof option === "object" && option !== null ? option.value : option);
  const optionLabel = (option) => (typeof option === "object" && option !== null ? (option.label || option.value) : option);
  const makeOption = (value, label) => {
    const normalizedValue = `${value || ""}`.trim();
    if (!normalizedValue) return null;
    return { value: normalizedValue, label: `${label || normalizedValue}`.trim() || normalizedValue };
  };
  const optionWithFallbackName = (value, label, fallbackName) => {
    const normalizedValue = `${value || ""}`.trim();
    const normalizedLabel = `${label || ""}`.trim();
    if (!normalizedValue) return null;
    if (displayNameFromLabel(normalizedLabel) || !fallbackName) return makeOption(normalizedValue, normalizedLabel || normalizedValue);

    return makeOption(normalizedValue, `${normalizedValue} (${fallbackName})`);
  };
  const uniqueOptions = (options) => {
    const seen = new Set();
    return options.filter((option) => {
      if (!option) return false;

      const value = normalizeOption(optionValue(option));
      const label = `${optionLabel(option) || ""}`.trim().toLowerCase();
      const key = [value, label].join("|");
      if (!value || seen.has(key)) return false;

      seen.add(key);
      return true;
    });
  };

  const replaceSelectOptions = (select, values, blankLabel, selectedValue) => {
    if (!select) return;

    const selected = selectedValue || select.dataset.selectedValue || select.value;
    const normalizedSelected = normalizeOption(selected);
    const valueList = values.map((value) => optionValue(value));
    select.innerHTML = "";

    const blankOption = document.createElement("option");
    blankOption.value = "";
    blankOption.textContent = blankLabel;
    select.appendChild(blankOption);

    values.forEach((value) => {
      const option = document.createElement("option");
      option.value = stripDisplayName(optionValue(value));
      option.textContent = optionLabel(value);
      option.selected = normalizeOption(option.value) === normalizedSelected;
      select.appendChild(option);
    });

    if (select.dataset.strictOptions === "true") return;

    if (selected && !valueList.some((value) => normalizeOption(value) === normalizedSelected)) {
      const option = document.createElement("option");
      option.value = stripDisplayName(selected);
      option.textContent = selected;
      option.selected = true;
      select.appendChild(option);
    }
  };

  document.querySelectorAll("[data-user-role-form]").forEach((formShell) => {
    const stakeholderSelect = formShell.querySelector("[data-role-stakeholder-select]");
    const stakeholderRoleSelect = formShell.querySelector("[data-stakeholder-role-select]");
    const roleSelect = formShell.querySelector("[data-role-select]");
    const roleNameSelect = formShell.querySelector("[data-role-name-select]");
    const userManagementRoleSelect = formShell.querySelector("[data-user-management-role-select]");
    const personTypeSelect = formShell.querySelector("[data-person-type-select]");
    const parentOfficeSelect = formShell.querySelector("[data-parent-office-select]");
    const officeCategorySelect = formShell.querySelector("[data-office-category-select]");
    const officeNameSelect = formShell.querySelector("[data-office-name-select]");
    const subOfficeSelect = formShell.querySelector("[data-sub-office-name-select]");
    const officeSelect = subOfficeSelect || officeNameSelect || formShell.querySelector("[data-office-select]");
    const officeUserSelect = formShell.querySelector("[data-office-user-select]");
    const approvalOfficeCascade = formShell.dataset.approvalOfficeCascade === "true";
    if (!stakeholderSelect && !stakeholderRoleSelect && !roleSelect && !roleNameSelect && !userManagementRoleSelect && !personTypeSelect && !parentOfficeSelect && !officeCategorySelect && !officeNameSelect && !subOfficeSelect && !officeSelect && !officeUserSelect) return;

    let mappings = [];
    try {
      mappings = JSON.parse(formShell.dataset.roleMap || "[]");
    } catch (_error) {
      mappings = [];
    }
    let officeMappings = [];
    try {
      officeMappings = JSON.parse(formShell.dataset.officeMap || "[]");
    } catch (_error) {
      officeMappings = [];
    }
    let officeUserMappings = [];
    try {
      officeUserMappings = JSON.parse(formShell.dataset.officeUserMap || "[]");
    } catch (_error) {
      officeUserMappings = [];
    }
    const selectedDisplayName = (select) => {
      if (!select) return "";

      const selectedOption = select.options[select.selectedIndex];
      return displayNameFromLabel(selectedOption?.textContent || select.value);
    };
    const initialParentOfficeOptions = parentOfficeSelect
      ? Array.from(parentOfficeSelect.options).map((option) => option.value).filter(Boolean)
      : [];
    const initialOfficeNameOptions = officeNameSelect
      ? Array.from(officeNameSelect.options).map((option) => option.value).filter(Boolean)
      : [];
    const initialOfficeUserOptions = officeUserSelect
      ? Array.from(officeUserSelect.options)
          .filter((option) => option.value)
          .map((option) => makeOption(option.value, option.textContent))
      : [];

    const mappedStakeholderRoles = (stakeholder) => {
      const normalizedStakeholder = normalizeOption(stakeholder);
      if (!normalizedStakeholder) return [];

      const filtered = mappings.filter((mapping) => {
        return normalizeOption(mapping.stakeholder) === normalizedStakeholder;
      });
      const stakeholderRoles = uniqueOptions(filtered.map((mapping) => makeOption(mapping.stakeholder_role, mapping.stakeholder_role_label)));
      return stakeholderRoles;
    };

    const mappedRoles = (stakeholder, stakeholderRole) => {
      const normalizedStakeholder = normalizeOption(stakeholder);
      const normalizedStakeholderRole = normalizeOption(stakeholderRole);
      if (!normalizedStakeholder) return [];

      const filtered = mappings.filter((mapping) => {
        const stakeholderMatches = normalizeOption(mapping.stakeholder) === normalizedStakeholder;
        const mappedStakeholderRole = normalizeOption(mapping.stakeholder_role);
        const stakeholderRoleMatches = !mappedStakeholderRole || mappedStakeholderRole === normalizedStakeholderRole;
        return stakeholderMatches && stakeholderRoleMatches;
      });
      const fallbackName = selectedDisplayName(stakeholderRoleSelect);
      const roles = uniqueOptions(filtered.map((mapping) => optionWithFallbackName(mapping.role, mapping.role_label, fallbackName)));
      return roles;
    };

    const mappedRoleNames = (stakeholder, stakeholderRole) => {
      const normalizedStakeholder = normalizeOption(stakeholder);
      const normalizedStakeholderRole = normalizeOption(stakeholderRole);
      if (!normalizedStakeholder || !normalizedStakeholderRole) return [];

      const filtered = mappings.filter((mapping) => {
        const stakeholderMatches = normalizeOption(mapping.stakeholder) === normalizedStakeholder;
        const stakeholderRoleMatches = normalizeOption(mapping.stakeholder_role) === normalizedStakeholderRole;
        return stakeholderMatches && stakeholderRoleMatches;
      });
      const fallbackName = selectedDisplayName(stakeholderRoleSelect);
      const roleNames = uniqueOptions(filtered.map((mapping) => optionWithFallbackName(mapping.role_name, mapping.role_name_label, fallbackName)));
      return roleNames;
    };

    const mappedUserManagementRoles = (stakeholder, stakeholderRole, role) => {
      const normalizedStakeholder = normalizeOption(stakeholder);
      const normalizedStakeholderRole = normalizeOption(stakeholderRole);
      const normalizedRole = normalizeOption(role);
      if (!normalizedStakeholder || !normalizedStakeholderRole || !normalizedRole) return [];

      const filtered = mappings.filter((mapping) => {
        const stakeholderMatches = normalizeOption(mapping.stakeholder) === normalizedStakeholder;
        const stakeholderRoleMatches = normalizeOption(mapping.stakeholder_role) === normalizedStakeholderRole;
        const roleMatches = normalizeOption(mapping.role) === normalizedRole;
        return stakeholderMatches && stakeholderRoleMatches && roleMatches;
      });
      const fallbackName = selectedDisplayName(roleSelect) || selectedDisplayName(stakeholderRoleSelect);
      const userManagementRoles = uniqueOptions(filtered.map((mapping) => optionWithFallbackName(mapping.user_management_role, mapping.user_management_role_label, fallbackName)));
      return userManagementRoles;
    };

    const mappedPersonTypes = (stakeholder, stakeholderRole, role, userManagementRole) => {
      const normalizedStakeholder = normalizeOption(stakeholder);
      const normalizedStakeholderRole = normalizeOption(stakeholderRole);
      const normalizedRole = normalizeOption(role);
      const normalizedUserManagementRole = normalizeOption(userManagementRole);
      if (!normalizedStakeholder || !normalizedStakeholderRole || !normalizedRole || !normalizedUserManagementRole) return [];

      const filtered = mappings.filter((mapping) => {
        const stakeholderMatches = normalizeOption(mapping.stakeholder) === normalizedStakeholder;
        const stakeholderRoleMatches = normalizeOption(mapping.stakeholder_role) === normalizedStakeholderRole;
        const roleMatches = normalizeOption(mapping.role) === normalizedRole;
        const userManagementRoleMatches = normalizeOption(mapping.user_management_role) === normalizedUserManagementRole;
        return stakeholderMatches && stakeholderRoleMatches && roleMatches && userManagementRoleMatches;
      });
      const fallbackName = selectedDisplayName(userManagementRoleSelect) || selectedDisplayName(roleSelect) || selectedDisplayName(stakeholderRoleSelect);
      const personTypes = uniqueOptions(filtered.map((mapping) => optionWithFallbackName(mapping.person_type, mapping.person_type_label, fallbackName)));
      return personTypes;
    };

    const refreshStakeholderRoles = () => {
      if (!stakeholderRoleSelect) return;
      const stakeholderRoles = mappedStakeholderRoles(stakeholderSelect?.value);
      replaceSelectOptions(stakeholderRoleSelect, stakeholderRoles, "Select Stakeholder Person Type");
    };

    const refreshRoles = () => {
      if (!roleSelect) return;
      const roles = mappedRoles(stakeholderSelect?.value, stakeholderRoleSelect?.value);
      replaceSelectOptions(roleSelect, roles, roleSelect.dataset.rolePrompt || "Select Role");
      refreshUserManagementRoles();
    };

    const refreshRoleNames = () => {
      if (!roleNameSelect) return;
      const roleNames = mappedRoleNames(stakeholderSelect?.value, stakeholderRoleSelect?.value);
      replaceSelectOptions(roleNameSelect, roleNames, "Select Role Name");
    };

    const refreshUserManagementRoles = () => {
      if (!userManagementRoleSelect) return;
      const userManagementRoles = mappedUserManagementRoles(stakeholderSelect?.value, stakeholderRoleSelect?.value, roleSelect?.value);
      replaceSelectOptions(userManagementRoleSelect, userManagementRoles, "Select User Management Person Type");
      refreshPersonTypes();
    };

    const refreshPersonTypes = () => {
      if (!personTypeSelect) return;
      const personTypes = mappedPersonTypes(stakeholderSelect?.value, stakeholderRoleSelect?.value, roleSelect?.value, userManagementRoleSelect?.value);
      replaceSelectOptions(personTypeSelect, personTypes, "Select Person Type");
    };

    const refreshParentOffices = () => {
      if (!parentOfficeSelect) return;
      const normalizedStakeholder = normalizeOption(stakeholderSelect?.value);
      const normalizedStakeholderRole = normalizeOption(stakeholderRoleSelect?.value);
      const mappedParentOffices = uniquePresent(
        officeMappings
          .filter((mapping) => {
            const mappedStakeholder = normalizeOption(mapping.stakeholder);
            const mappedStakeholderRole = normalizeOption(mapping.stakeholder_role);
            const stakeholderMatches = !normalizedStakeholder || !mappedStakeholder || mappedStakeholder === normalizedStakeholder;
            const stakeholderRoleMatches = !normalizedStakeholderRole || !mappedStakeholderRole || mappedStakeholderRole === normalizedStakeholderRole;
            return stakeholderMatches && stakeholderRoleMatches;
          })
          .map((mapping) => mapping.parent_office || mapping.office_category || (!mapping.office_name ? mapping.office : ""))
      );
      const parentOffices = uniquePresent(initialParentOfficeOptions.concat(mappedParentOffices));
      replaceSelectOptions(parentOfficeSelect, parentOffices, "Select Parent Office Name");
    };

    const officeMappingMatches = (mapping, stakeholder, parentOffice, officeCategory = "") => {
      const normalizedStakeholder = normalizeOption(stakeholder);
      const normalizedStakeholderRole = normalizeOption(stakeholderRoleSelect?.value);
      const normalizedParentOffice = normalizeOption(parentOffice);
      const normalizedOfficeCategory = normalizeOption(officeCategory);

      const mappedStakeholder = normalizeOption(mapping.stakeholder);
      const mappedStakeholderRole = normalizeOption(mapping.stakeholder_role);
      const mappedParentOffice = normalizeOption(mapping.parent_office);
      const mappedOfficeCategory = normalizeOption(mapping.office_category || mapping.category_name || (!mapping.office_name ? mapping.office : ""));
      const stakeholderMatches = approvalOfficeCascade
        ? mappedStakeholder === normalizedStakeholder
        : (!normalizedStakeholder || !mappedStakeholder || mappedStakeholder === normalizedStakeholder);
      const stakeholderRoleMatches = !normalizedStakeholderRole || !mappedStakeholderRole || mappedStakeholderRole === normalizedStakeholderRole;
      const parentOfficeMatches = !normalizedParentOffice || !mappedParentOffice || mappedParentOffice === normalizedParentOffice;
      const officeCategoryMatches = approvalOfficeCascade
        ? mappedOfficeCategory === normalizedOfficeCategory
        : (!normalizedOfficeCategory || !mappedOfficeCategory || mappedOfficeCategory === normalizedOfficeCategory);
      return stakeholderMatches && stakeholderRoleMatches && parentOfficeMatches && officeCategoryMatches;
    };

    const refreshOfficeNames = () => {
      if (!officeNameSelect) return;

      const normalizedStakeholder = normalizeOption(stakeholderSelect?.value);
      const normalizedParentOffice = normalizeOption(parentOfficeSelect?.value);
      if (!normalizedStakeholder && !normalizedParentOffice) {
        replaceSelectOptions(officeNameSelect, [], "Select Office Name");
        refreshOffices();
        return;
      }

      const officeNames = uniquePresent(
        officeMappings
          .filter((mapping) => {
            const mappedStakeholder = normalizeOption(mapping.stakeholder);
            const mappedParentOffice = normalizeOption(mapping.parent_office);
            const hasSubOffice = normalizeOption(mapping.office_name || mapping.sub_office_name);
            const stakeholderMatches = !normalizedStakeholder || !mappedStakeholder || mappedStakeholder === normalizedStakeholder;
            const parentOfficeMatches = !normalizedParentOffice || !mappedParentOffice || mappedParentOffice === normalizedParentOffice;
            return stakeholderMatches && parentOfficeMatches && !hasSubOffice;
          })
          .map((mapping) => mapping.office_category || mapping.category_name || mapping.office)
      );
      const options = normalizedStakeholder || normalizedParentOffice ? officeNames : uniquePresent(initialOfficeNameOptions.concat(officeNames));
      replaceSelectOptions(officeNameSelect, options, "Select Office Name");
      refreshOffices();
    };

    const refreshOfficeCategories = () => {
      if (!officeCategorySelect) return;
      const normalizedStakeholder = normalizeOption(stakeholderSelect?.value);
      const normalizedParentOffice = normalizeOption(parentOfficeSelect?.value);
      if (approvalOfficeCascade && !normalizedStakeholder) {
        replaceSelectOptions(officeCategorySelect, [], "Select Office Category");
        refreshOffices();
        return;
      }

      const officeCategories = uniquePresent(
        officeMappings
          .filter((mapping) => {
            const mappedStakeholder = normalizeOption(mapping.stakeholder);
            const mappedParentOffice = normalizeOption(mapping.parent_office);
            const stakeholderMatches = approvalOfficeCascade
              ? mappedStakeholder === normalizedStakeholder
              : (!normalizedStakeholder || !mappedStakeholder || mappedStakeholder === normalizedStakeholder);
            const parentOfficeMatches = !normalizedParentOffice || !mappedParentOffice || mappedParentOffice === normalizedParentOffice;
            return stakeholderMatches && parentOfficeMatches;
          })
          .map((mapping) => mapping.office_category || mapping.category_name || (!mapping.office_name ? mapping.office : ""))
      );
      replaceSelectOptions(officeCategorySelect, officeCategories, "Select Office Category");
      refreshOffices();
    };

    const refreshOffices = () => {
      if (!officeSelect) return;
      const selectedStakeholder = stakeholderSelect?.value || "";
      const selectedOfficeCategory = officeCategorySelect?.value || officeNameSelect?.value || "";
      if (subOfficeSelect && !normalizeOption(officeNameSelect?.value)) {
        replaceSelectOptions(subOfficeSelect, [], "Select Sub Office Name");
        refreshOfficeUsers();
        return;
      }

      if (approvalOfficeCascade && (!normalizeOption(selectedStakeholder) || !normalizeOption(selectedOfficeCategory))) {
        replaceSelectOptions(officeSelect, [], subOfficeSelect ? "Select Sub Office Name" : (officeNameSelect ? "Select Office Name" : "Select Office"));
        refreshOfficeUsers();
        return;
      }

      const offices = uniquePresent(
        officeMappings
          .filter((mapping) => {
            const hasSubOffice = normalizeOption(mapping.office_name || mapping.sub_office_name);
            return officeMappingMatches(mapping, selectedStakeholder, parentOfficeSelect?.value, selectedOfficeCategory) &&
              (!subOfficeSelect || hasSubOffice);
          })
          .map((mapping) => {
            if (subOfficeSelect) return mapping.office_name || mapping.sub_office_name || "";
            if (officeNameSelect) return mapping.office_name || "";

            return mapping.office || mapping.office_name || mapping.office_category;
          })
      );
      replaceSelectOptions(officeSelect, offices, subOfficeSelect ? "Select Sub Office Name" : (officeNameSelect ? "Select Office Name" : "Select Office"));
      refreshOfficeUsers();
    };

    const refreshOfficeUsers = () => {
      if (!officeUserSelect) return;

      const selectedOfficeCategory = normalizeOption(officeCategorySelect?.value);
      const selectedOfficeName = normalizeOption(officeSelect?.value);
      const selectedStakeholder = normalizeOption(stakeholderSelect?.value);
      if (approvalOfficeCascade && (!selectedStakeholder || !selectedOfficeCategory || !selectedOfficeName)) {
        replaceSelectOptions(officeUserSelect, [], "Select User Name");
        return;
      }

      const filteredUsers = officeUserMappings.filter((user) => {
        const mappedStakeholder = normalizeOption(user.stakeholder || user.stakeholder_name || user.stakeholder_category);
        const mappedOfficeCategory = normalizeOption(user.office_category || user.category_name);
        const mappedOfficeName = normalizeOption(user.office_name || user.office);
        const stakeholderMatches = approvalOfficeCascade
          ? mappedStakeholder === selectedStakeholder
          : (!selectedStakeholder || !mappedStakeholder || mappedStakeholder === selectedStakeholder);
        const categoryMatches = approvalOfficeCascade
          ? mappedOfficeCategory === selectedOfficeCategory
          : (!selectedOfficeCategory || !mappedOfficeCategory || mappedOfficeCategory === selectedOfficeCategory);
        const officeMatches = !selectedOfficeName || mappedOfficeName === selectedOfficeName;
        return stakeholderMatches && categoryMatches && officeMatches;
      });
      const users = uniqueOptions(
        (filteredUsers.length ? filteredUsers : (!selectedOfficeCategory && !selectedOfficeName ? officeUserMappings : []))
          .map((user) => makeOption(user.value, user.label || user.value))
      );
      const options = users.length ? users : (officeUserMappings.length ? [] : initialOfficeUserOptions);
      replaceSelectOptions(officeUserSelect, options, options.length ? "Select User Name" : "No User saved yet");
    };

    stakeholderSelect?.addEventListener("change", () => {
      if (stakeholderRoleSelect) stakeholderRoleSelect.dataset.selectedValue = "";
      if (roleSelect) roleSelect.dataset.selectedValue = "";
      if (roleNameSelect) roleNameSelect.dataset.selectedValue = "";
      if (userManagementRoleSelect) userManagementRoleSelect.dataset.selectedValue = "";
      if (personTypeSelect) personTypeSelect.dataset.selectedValue = "";
      if (parentOfficeSelect) parentOfficeSelect.dataset.selectedValue = "";
      if (officeCategorySelect) officeCategorySelect.dataset.selectedValue = "";
      if (officeNameSelect) officeNameSelect.dataset.selectedValue = "";
      if (subOfficeSelect) subOfficeSelect.dataset.selectedValue = "";
      if (officeSelect) officeSelect.dataset.selectedValue = "";
      refreshStakeholderRoles();
      refreshRoles();
      refreshRoleNames();
      refreshUserManagementRoles();
      refreshPersonTypes();
      refreshParentOffices();
      refreshOfficeCategories();
      refreshOfficeNames();
      refreshOffices();
    });
    parentOfficeSelect?.addEventListener("change", () => {
      if (officeCategorySelect) officeCategorySelect.dataset.selectedValue = "";
      if (officeNameSelect) officeNameSelect.dataset.selectedValue = "";
      if (subOfficeSelect) subOfficeSelect.dataset.selectedValue = "";
      if (officeSelect) officeSelect.dataset.selectedValue = "";
      refreshOfficeCategories();
      refreshOfficeNames();
      refreshOffices();
    });
    officeCategorySelect?.addEventListener("change", () => {
      if (officeSelect) officeSelect.dataset.selectedValue = "";
      if (officeUserSelect) officeUserSelect.dataset.selectedValue = "";
      refreshOffices();
    });
    officeNameSelect?.addEventListener("change", () => {
      if (!subOfficeSelect) return;

      subOfficeSelect.dataset.selectedValue = "";
      if (officeUserSelect) officeUserSelect.dataset.selectedValue = "";
      refreshOffices();
    });
    officeSelect?.addEventListener("change", () => {
      if (officeUserSelect) officeUserSelect.dataset.selectedValue = "";
      refreshOfficeUsers();
    });
    stakeholderRoleSelect?.addEventListener("change", () => {
      if (roleSelect) roleSelect.dataset.selectedValue = "";
      if (roleNameSelect) roleNameSelect.dataset.selectedValue = "";
      if (userManagementRoleSelect) userManagementRoleSelect.dataset.selectedValue = "";
      if (personTypeSelect) personTypeSelect.dataset.selectedValue = "";
      if (parentOfficeSelect) parentOfficeSelect.dataset.selectedValue = "";
      if (officeCategorySelect) officeCategorySelect.dataset.selectedValue = "";
      if (officeNameSelect) officeNameSelect.dataset.selectedValue = "";
      if (subOfficeSelect) subOfficeSelect.dataset.selectedValue = "";
      if (officeSelect) officeSelect.dataset.selectedValue = "";
      refreshRoles();
      refreshRoleNames();
      refreshUserManagementRoles();
      refreshPersonTypes();
      refreshParentOffices();
      refreshOfficeCategories();
      refreshOfficeNames();
      refreshOffices();
    });
    roleSelect?.addEventListener("change", () => {
      if (userManagementRoleSelect) userManagementRoleSelect.dataset.selectedValue = "";
      if (personTypeSelect) personTypeSelect.dataset.selectedValue = "";
      refreshUserManagementRoles();
      refreshPersonTypes();
    });
    userManagementRoleSelect?.addEventListener("change", () => {
      if (personTypeSelect) personTypeSelect.dataset.selectedValue = "";
      refreshPersonTypes();
    });

    refreshStakeholderRoles();
    refreshRoles();
    refreshRoleNames();
    refreshParentOffices();
    refreshOfficeCategories();
    refreshOfficeNames();
    refreshOffices();
    refreshOfficeUsers();
  });

  document.querySelectorAll("[data-parent-office-form]").forEach((formShell) => {
    const stakeholderSelect = formShell.querySelector("[data-parent-office-stakeholder-select]");
    const parentOfficeTypeSelect = formShell.querySelector("[data-parent-office-type-select]");
    const parentOfficeSelect = formShell.querySelector("[data-parent-office-select]");
    if (!parentOfficeTypeSelect && !parentOfficeSelect) return;

    let parentOfficeMappings = [];
    try {
      parentOfficeMappings = JSON.parse(formShell.dataset.parentOfficeMap || "[]");
    } catch (_error) {
      parentOfficeMappings = [];
    }

    const parentOfficeLabel = parentOfficeSelect?.closest("label");
    const initialParentOfficeOptions = parentOfficeSelect
      ? Array.from(parentOfficeSelect.options).map((option) => option.value).filter(Boolean)
      : [];

    const parentOfficeOptions = () => {
      const options = uniquePresent(
        parentOfficeMappings
          .map((mapping) => mapping.parent_office_name)
      );

      return options.length ? options : initialParentOfficeOptions;
    };

    const refreshParentOfficeField = () => {
      if (!parentOfficeSelect) return;

      const selectedType = normalizeOption(parentOfficeTypeSelect?.value);
      const isSubParentOffice = selectedType === normalizeOption("Sub Parent Office");

      if (parentOfficeLabel) parentOfficeLabel.hidden = false;
      parentOfficeSelect.disabled = !isSubParentOffice;
      parentOfficeSelect.required = isSubParentOffice;
      if (!isSubParentOffice) {
        parentOfficeSelect.value = "";
        parentOfficeSelect.dataset.selectedValue = "";
        return;
      }

      replaceSelectOptions(parentOfficeSelect, parentOfficeOptions(), "Select Parent Office");
    };

    stakeholderSelect?.addEventListener("change", () => {
      if (parentOfficeSelect) parentOfficeSelect.dataset.selectedValue = "";
      refreshParentOfficeField();
    });

    parentOfficeTypeSelect?.addEventListener("change", () => {
      if (parentOfficeSelect) parentOfficeSelect.dataset.selectedValue = "";
      refreshParentOfficeField();
    });

    refreshParentOfficeField();
  });

  document.querySelectorAll("[data-vrp-office-form]").forEach((formShell) => {
    const officeCategorySelect = formShell.querySelector("[data-vrp-office-category]");
    const officeNameSelect = formShell.querySelector("[data-vrp-office-name]");
    const clusterInchargeSelect = formShell.querySelector("[data-vrp-cluster-incharge]");
    if (!officeCategorySelect && !officeNameSelect && !clusterInchargeSelect) return;

    let officeMappings = [];
    let clusterUsers = [];
    try {
      officeMappings = JSON.parse(formShell.dataset.officeMap || "[]");
    } catch (_error) {
      officeMappings = [];
    }
    try {
      clusterUsers = JSON.parse(formShell.dataset.clusterUsers || "[]");
    } catch (_error) {
      clusterUsers = [];
    }

    const mappedOfficeNames = (officeCategory) => {
      const normalizedOfficeCategory = normalizeOption(officeCategory);
      return uniquePresent(
        officeMappings
          .filter((mapping) => {
            const mappedOfficeCategory = normalizeOption(mapping.office_category || mapping.category_name);
            return !normalizedOfficeCategory || mappedOfficeCategory === normalizedOfficeCategory;
          })
          .map((mapping) => mapping.office_name || mapping.office)
      );
    };

    const mappedClusterUsers = (officeCategory, officeName) => {
      const normalizedOfficeCategory = normalizeOption(officeCategory);
      const normalizedOfficeName = normalizeOption(officeName);
      return uniqueOptions(
        clusterUsers
          .filter((user) => {
            const userOfficeCategory = normalizeOption(user.office_category);
            const userOfficeName = normalizeOption(user.office_name || user.office);
            const hierarchyOnlyMapping = !userOfficeCategory && !userOfficeName;
            const categoryMatches = hierarchyOnlyMapping || !normalizedOfficeCategory || userOfficeCategory === normalizedOfficeCategory;
            const officeMatches = hierarchyOnlyMapping || !normalizedOfficeName || userOfficeName === normalizedOfficeName;
            return categoryMatches && officeMatches;
          })
          .map((user) => makeOption(user.value, user.label || user.value))
      );
    };

    const refreshOfficeNames = () => {
      if (!officeNameSelect) return;

      const offices = mappedOfficeNames(officeCategorySelect?.value);
      replaceSelectOptions(officeNameSelect, offices, "Select TO");
      refreshClusterIncharges();
    };

    const refreshClusterIncharges = () => {
      if (!clusterInchargeSelect) return;

      const users = mappedClusterUsers(officeCategorySelect?.value, officeNameSelect?.value);
      replaceSelectOptions(clusterInchargeSelect, users, "Select Cluster Incharge");
    };

    officeCategorySelect?.addEventListener("change", () => {
      if (officeNameSelect) officeNameSelect.dataset.selectedValue = "";
      if (clusterInchargeSelect) clusterInchargeSelect.dataset.selectedValue = "";
      refreshOfficeNames();
      refreshClusterIncharges();
    });
    officeNameSelect?.addEventListener("change", () => {
      if (clusterInchargeSelect) clusterInchargeSelect.dataset.selectedValue = "";
      refreshClusterIncharges();
    });

    refreshOfficeNames();
    refreshClusterIncharges();
  });

  document.querySelectorAll("[data-max-size-mb]").forEach((input) => {
    input.addEventListener("change", () => {
      const maxSizeMb = Number(input.dataset.maxSizeMb || 0);
      const files = Array.from(input.files || []);
      if (!maxSizeMb || files.length === 0) return;

      const oversizedFiles = files.filter((file) => file.size > maxSizeMb * 1024 * 1024);
      if (oversizedFiles.length > 0) {
        window.alert(`Each photo must be ${maxSizeMb} MB or smaller. Please reselect the photos.`);
        input.value = "";
      }
    });
  });

  const uploadGalleryModal = document.querySelector("[data-upload-gallery-modal]");
  const uploadGalleryGrid = uploadGalleryModal?.querySelector("[data-upload-gallery-grid]");
  const uploadGalleryCount = uploadGalleryModal?.querySelector("[data-upload-gallery-count]");

  const clearUploadGallery = () => {
    if (uploadGalleryGrid) uploadGalleryGrid.replaceChildren();
  };

  document.querySelectorAll("[data-upload-gallery]").forEach((button) => {
    button.addEventListener("click", () => {
      if (!uploadGalleryModal || !uploadGalleryGrid) return;

      let urls = [];
      try {
        urls = JSON.parse(button.dataset.uploadUrls || "[]");
      } catch (_error) {
        urls = [];
      }

      clearUploadGallery();
      urls.forEach((url, index) => {
        const link = document.createElement("a");
        link.href = url;
        link.target = "_blank";
        link.rel = "noopener";
        link.className = "module-gallery-item";

        const image = document.createElement("img");
        image.src = url;
        image.alt = `Training photo ${index + 1}`;
        image.loading = "lazy";
        image.decoding = "async";
        link.appendChild(image);
        uploadGalleryGrid.appendChild(link);
      });

      if (uploadGalleryCount) uploadGalleryCount.textContent = `${urls.length} photo${urls.length === 1 ? "" : "s"}`;
      uploadGalleryModal.showModal();
    });
  });

  uploadGalleryModal?.querySelector("[data-upload-gallery-close]")?.addEventListener("click", () => {
    uploadGalleryModal.close();
  });
  uploadGalleryModal?.addEventListener("click", (event) => {
    if (event.target === uploadGalleryModal) uploadGalleryModal.close();
  });
  uploadGalleryModal?.addEventListener("close", clearUploadGallery);

  const locationLevels = ["state", "district", "block", "gram-panchayat", "village"];
  const locationKeys = {
    "state": "state",
    "district": "district",
    "block": "block",
    "gram-panchayat": "gram_panchayat",
    "village": "village"
  };
  const locationParents = {
    "district": ["state"],
    "block": ["state", "district"],
    "gram-panchayat": ["state", "district", "block"],
    "village": ["state", "district", "block", "gram-panchayat"]
  };
  const locationAliasKeys = {
    state: ["state", "state_id", "state_code"],
    district: ["district", "district_id", "district_code"],
    block: ["block", "block_id", "block_code"],
    gram_panchayat: ["gram_panchayat", "gram_panchayat_id", "gram_panchayat_code", "gp_code", "gram_code", "gp_name", "gram_name"],
    village: ["village", "village_id", "village_code"]
  };

  const locationSelectedValuesFromDataset = (select) => {
    if (!select) return [];

    if (select.dataset.selectedValues) {
      try {
        const values = JSON.parse(select.dataset.selectedValues);
        if (Array.isArray(values)) return values.map((value) => String(value));
      } catch (_error) {
        return select.dataset.selectedValues.split(",").map((value) => value.trim());
      }
    }

    return select.dataset.selectedValue ? [select.dataset.selectedValue] : [];
  };

  const selectedLocationValues = (select) => {
    if (!select) return [];

    const selectedOptions = Array.from(select.selectedOptions || []).filter((option) => option.value);
    if (selectedOptions.length === 0) return [];

    return uniquePresent(selectedOptions.flatMap((option) => [option.value, option.textContent]));
  };

  const locationRowValues = (row, key) => {
    return uniquePresent((locationAliasKeys[key] || [key]).map((alias) => row[alias]));
  };

  const locationRowMatchesParents = (row, selects, level) => {
    const parents = locationParents[level] || [];
    const immediateParent = parents[parents.length - 1];
    return parents.every((parentLevel) => {
      const parentValues = selectedLocationValues(selects[parentLevel]);
      if (parentValues.length === 0) return false;

      const parentKey = locationKeys[parentLevel];
      const rowValues = locationRowValues(row, parentKey);
      if (rowValues.length === 0) return parentLevel !== immediateParent;

      return parentValues.some((value) => {
        const normalizedValue = normalizeOption(value);
        return rowValues.some((rowValue) => normalizeOption(rowValue) === normalizedValue);
      });
    });
  };

  const optionMatchesLocationRow = (option, row, level) => {
    const key = locationKeys[level];
    return [row.id].concat(locationRowValues(row, key)).some((value) => {
      return normalizeOption(value) === normalizeOption(option.value) ||
        normalizeOption(value) === normalizeOption(option.textContent);
    });
  };

  const replaceLocationOptions = (select, originalOptions, allowedRows, level) => {
    if (!select) return;

    const selectedValues = uniquePresent(locationSelectedValuesFromDataset(select).concat(selectedLocationValues(select)));
    const blankOption = originalOptions.find((option) => option.value === "") || { value: "", label: `Select ${level}` };
    const filteredOptions = originalOptions.filter((option) => {
      if (option.value === "") return false;
      return allowedRows.some((row) => optionMatchesLocationRow(option, row, level));
    });

    const parentSelected = (locationParents[level] || []).every((parentLevel) => {
      return selectedLocationValues(select.closest("[data-location-form]")?.querySelector(`[data-location-level="${parentLevel}"]`)).length > 0;
    });
    const hasParents = (locationParents[level] || []).length > 0;
    const fallbackOptions = originalOptions.filter((option) => option.value !== "");
    const finalOptions = hasParents && !parentSelected
      ? []
      : (hasParents ? filteredOptions : fallbackOptions);
    finalOptions.sort((left, right) => left.label.localeCompare(right.label, undefined, { sensitivity: "base" }));
    select.innerHTML = "";

    const prompt = document.createElement("option");
    prompt.value = "";
    prompt.textContent = blankOption.label;
    select.appendChild(prompt);

    finalOptions.forEach((optionData) => {
      const option = document.createElement("option");
      option.value = optionData.value;
      option.textContent = optionData.label;
      option.selected = selectedValues.some((selected) => optionData.value === selected || optionData.label === selected);
      select.appendChild(option);
    });
    select.dispatchEvent(new Event("chip:refresh"));
  };

  document.querySelectorAll("[data-location-form]").forEach((formShell) => {
    let mappings = [];
    try {
      mappings = JSON.parse(formShell.dataset.locationMap || "[]");
    } catch (_error) {
      mappings = [];
    }

    const selects = {};
    const originalOptions = {};
    locationLevels.forEach((level) => {
      const select = formShell.querySelector(`[data-location-level="${level}"]`);
      if (!select) return;

      selects[level] = select;
      originalOptions[level] = Array.from(select.options).map((option) => ({
        value: option.value,
        label: option.textContent
      }));
    });

    const syncLocationPrimary = (level) => {
      const select = selects[level];
      const hidden = formShell.querySelector(`[data-location-primary="${level}"]`);
      if (!select || !hidden) return;

      hidden.value = Array.from(select.selectedOptions || []).find((option) => option.value)?.value || "";
    };

    const syncLocationPrimaries = () => {
      Object.keys(selects).forEach(syncLocationPrimary);
    };

    const refreshLocationLevel = (level) => {
      if (!selects[level]) return;

      const key = locationKeys[level];
      const allowedRows = mappings.filter((row) => row[key] && locationRowMatchesParents(row, selects, level));
      replaceLocationOptions(selects[level], originalOptions[level], allowedRows, level);
      syncLocationPrimary(level);
    };

    const refreshFrom = (level) => {
      const startIndex = locationLevels.indexOf(level) + 1;
      locationLevels.slice(startIndex).forEach((childLevel) => {
        if (selects[childLevel]) {
          selects[childLevel].dataset.selectedValue = "";
          selects[childLevel].dataset.selectedValues = "[]";
        }
        refreshLocationLevel(childLevel);
      });
      syncLocationPrimaries();
    };

    locationLevels.forEach((level) => {
      selects[level]?.addEventListener("change", () => {
        delete selects[level].dataset.selectedValue;
        delete selects[level].dataset.selectedValues;
        syncLocationPrimary(level);
        refreshFrom(level);
      });
    });

    locationLevels.slice(1).forEach(refreshLocationLevel);
    syncLocationPrimaries();
  });

  document.querySelectorAll("[data-training-target-form]").forEach((formShell) => {
    if (formShell.dataset.trainingTargetBound === "true") return;
    formShell.dataset.trainingTargetBound = "true";
    formShell.querySelectorAll(".training-main-activity-chips, .training-sub-activity-chips").forEach((element) => element.remove());

    let mappings = [];
    let activityMappings = [];
    let monthOptions = [];
    try {
      mappings = JSON.parse(formShell.dataset.trainingTargetMap || "[]");
    } catch (_error) {
      mappings = [];
    }
    try {
      activityMappings = JSON.parse(formShell.dataset.trainingActivityMap || "[]");
    } catch (_error) {
      activityMappings = [];
    }
    try {
      monthOptions = JSON.parse(formShell.dataset.trainingMonthOptions || "[]");
    } catch (_error) {
      monthOptions = [];
    }
    mappings = mappings.filter((mapping) => normalizeOption(mapping.main_activity_type || "Training") === normalizeOption("Training"));
    activityMappings = activityMappings.filter((mapping) => normalizeOption(mapping.main_activity_type || "Training") === normalizeOption("Training"));

	    const monthSelect = formShell.querySelector("[data-training-target-month]");
	    const icsSelect = formShell.querySelector("[data-training-target-ics]");
	    const villageSelect = formShell.querySelector("[data-training-target-village]");
	    const mainActivityTypeSelect = formShell.querySelector("[data-training-main-activity-type]");
	    const mainActivitySelect = formShell.querySelector("[data-training-main-activity]");
	    const subActivitySelect = formShell.querySelector("[data-training-sub-activity]");
	    const farmerPanel = formShell.querySelector("[data-training-farmer-panel]");
	    const farmerList = formShell.querySelector("[data-training-farmer-list]");
	    const farmerSelectAll = formShell.querySelector("[data-training-farmer-select-all]");
	    const farmerSelectAllButton = formShell.querySelector("[data-training-farmer-select-all-button]");
	    const farmerCount = formShell.querySelector("[data-training-farmer-count]");
	    const farmerCountInput = formShell.querySelector("[data-training-farmer-count-input]");
	    const totalFarmerCountInput = formShell.querySelector("[data-training-total-farmer-count-input]");
	    const farmerSearchInput = formShell.querySelector("[data-training-farmer-search]");
	    const farmerSearchEmpty = formShell.querySelector("[data-training-farmer-search-empty]");
	    const maleCountInput = formShell.querySelector('input[name="module_record[male_count]"]');
	    const femaleCountInput = formShell.querySelector('input[name="module_record[female_count]"]');
	    const geoLatitudeInput = formShell.querySelector("[data-training-geo-latitude]");
	    const geoLongitudeInput = formShell.querySelector("[data-training-geo-longitude]");
	    if (!icsSelect || !villageSelect) return;
	    const selectedFarmerIds = new Set(JSON.parse(farmerPanel?.dataset.selectedFarmerIds || "[]").map(String));
    const farmersUrl = formShell.dataset.trainingFarmersUrl;
    const trainingFarmerCache = new Map();
    let activeFarmerLoadKey = "";
	    let mainActivityChips = null;
	    if (mainActivitySelect) {
	      mainActivityChips = document.createElement("div");
	      mainActivityChips.className = "training-sub-activity-chips training-main-activity-chips";
	      mainActivityChips.setAttribute("aria-live", "polite");
	      mainActivitySelect.insertAdjacentElement("afterend", mainActivityChips);
	    }
	    let subActivityChips = null;
	    if (subActivitySelect) {
	      subActivitySelect.classList.add("training-sub-activity-native");
	      subActivityChips = document.createElement("div");
	      subActivityChips.className = "training-sub-activity-chips";
	      subActivityChips.setAttribute("aria-live", "polite");
	      subActivitySelect.insertAdjacentElement("afterend", subActivityChips);
	    }

	    const escapeHtml = (value) => String(value || "")
	      .replaceAll("&", "&amp;")
	      .replaceAll("<", "&lt;")
	      .replaceAll(">", "&gt;")
	      .replaceAll('"', "&quot;")
	      .replaceAll("'", "&#039;");

    const selectOption = (option, optionData, selected) => {
      const value = optionValue(optionData);
      const label = optionLabel(optionData);
      option.selected = normalizeOption(value) === normalizeOption(selected) ||
        normalizeOption(label) === normalizeOption(selected);
    };

    const fillTrainingSelect = (select, options, placeholder) => {
      const selected = select.multiple
        ? (() => { try { return JSON.parse(select.dataset.selectedValues || "[]"); } catch (_error) { return []; } })()
        : (select.dataset.selectedValue || select.value);
      select.innerHTML = "";

      const blank = document.createElement("option");
      blank.value = "";
      blank.textContent = options.length ? placeholder : `No ${placeholder.replace(/^Select\s+/i, "")} saved yet`;
      select.appendChild(blank);

      options.forEach((optionData) => {
        const option = document.createElement("option");
        option.value = optionValue(optionData);
        option.textContent = optionLabel(optionData);
        if (select.multiple) {
          option.selected = selected.some((value) => normalizeOption(value) === normalizeOption(optionValue(optionData)));
        } else {
          selectOption(option, optionData, selected);
        }
        select.appendChild(option);
      });
    };

    const setOnlyTrainingOption = (select, options) => {
      if (!select || select.value || options.length !== 1) return;

      select.value = optionValue(options[0]);
      select.dataset.selectedValue = select.value;
    };

    const selectedSubActivityValues = () => subActivitySelect
      ? Array.from(subActivitySelect.selectedOptions).map((option) => option.value).filter(Boolean)
      : [];
    const selectedMainActivityValues = () => mainActivitySelect
      ? Array.from(mainActivitySelect.selectedOptions).map((option) => option.value).filter(Boolean)
      : [];

    const renderMainActivityChips = () => {
      if (!mainActivitySelect || !mainActivityChips) return;

      const selectedOptions = Array.from(mainActivitySelect.selectedOptions).filter((option) => option.value);
      mainActivityChips.innerHTML = "";
      if (!selectedOptions.length) {
        mainActivityChips.innerHTML = '<span class="training-sub-activity-empty">Mapped Main Activities select karein.</span>';
        return;
      }

      selectedOptions.forEach((option) => {
        const chip = document.createElement("span");
        chip.className = "training-sub-activity-chip";
        chip.append(document.createTextNode(option.textContent || option.value));
        const remove = document.createElement("button");
        remove.type = "button";
        remove.className = "training-sub-activity-remove";
        remove.setAttribute("aria-label", `Remove ${option.textContent || option.value}`);
        remove.textContent = "×";
        remove.addEventListener("click", () => {
          option.selected = false;
          mainActivitySelect.dataset.selectedValues = JSON.stringify(selectedMainActivityValues());
          renderMainActivityChips();
          mainActivitySelect.dispatchEvent(new Event("change", { bubbles: true }));
        });
        chip.appendChild(remove);
        mainActivityChips.appendChild(chip);
      });
    };

    const mappingMatchesSelectedSubActivities = (mapping, selectedValues) => {
      if (!selectedValues.length) return true;
      const mappedValue = normalizeOption(mapping.sub_activity);
      return selectedValues.some((value) => {
        const selectedValue = normalizeOption(value);
        return mappedValue === selectedValue || mappedValue.includes(selectedValue);
      });
    };

    const renderSubActivityChips = () => {
      if (!subActivitySelect || !subActivityChips) return;

      const selectedOptions = Array.from(subActivitySelect.selectedOptions).filter((option) => option.value);
      subActivityChips.innerHTML = "";
      if (!selectedOptions.length) {
        subActivityChips.innerHTML = '<span class="training-sub-activity-empty">Main Activity select karne par mapped Sub Activities yahan aayengi.</span>';
        return;
      }

      selectedOptions.forEach((option) => {
        const chip = document.createElement("span");
        chip.className = "training-sub-activity-chip";
        chip.append(document.createTextNode(option.textContent || option.value));
        const remove = document.createElement("button");
        remove.type = "button";
        remove.className = "training-sub-activity-remove";
        remove.setAttribute("aria-label", `Remove ${option.textContent || option.value}`);
        remove.textContent = "×";
        remove.addEventListener("click", () => {
          option.selected = false;
          subActivitySelect.dataset.selectedValues = JSON.stringify(selectedSubActivityValues());
          renderSubActivityChips();
          subActivitySelect.dispatchEvent(new Event("change", { bubbles: true }));
        });
        chip.appendChild(remove);
        subActivityChips.appendChild(chip);
      });
    };

    const autoSelectMappedSubActivities = () => {
      if (!subActivitySelect || !mainActivitySelect?.value) {
        renderSubActivityChips();
        return;
      }
      Array.from(subActivitySelect.options).forEach((option) => { option.selected = Boolean(option.value); });
      subActivitySelect.dataset.selectedValues = JSON.stringify(selectedSubActivityValues());
      renderSubActivityChips();
    };

    const autoSelectMappedMainActivities = () => {
      if (!mainActivitySelect) return;
      Array.from(mainActivitySelect.options).forEach((option) => { option.selected = Boolean(option.value); });
      mainActivitySelect.dataset.selectedValues = JSON.stringify(selectedMainActivityValues());
      renderMainActivityChips();
    };

    const targetRowsForSelection = ({
      requireMonth = false,
      requireVillage = false,
      includeMainActivity = true,
      requireMainActivity = false,
      includeSubActivity = true,
      requireSubActivity = false
    } = {}) => {
      const selectedMonth = normalizeOption(monthSelect?.value);
      const selectedIcs = normalizeOption(icsSelect.value);
      const selectedVillage = normalizeOption(villageSelect.value);
      const selectedMainActivities = includeMainActivity ? selectedMainActivityValues().map(normalizeOption) : [];
      const selectedSubActivities = includeSubActivity && subActivitySelect
        ? Array.from(subActivitySelect.selectedOptions).map((option) => normalizeOption(option.value)).filter(Boolean)
        : [];

      if (requireMonth && !selectedMonth) return [];
      if (requireVillage && !selectedVillage) return [];
      if (requireMainActivity && !selectedMainActivities.length) return [];
      if (requireSubActivity && !selectedSubActivities.length) return [];

      return mappings.filter((mapping) => {
        const monthMatches = !selectedMonth || normalizeOption(mapping.month) === selectedMonth;
        const icsMatches = !selectedIcs || normalizeOption(mapping.ics) === selectedIcs;
        const villageMatches = !selectedVillage || normalizeOption(mapping.village) === selectedVillage;
        const mainActivityMatches = !selectedMainActivities.length || selectedMainActivities.includes(normalizeOption(mapping.main_activity));
        const subActivityMatches = mappingMatchesSelectedSubActivities(mapping, selectedSubActivities);
        return monthMatches && icsMatches && villageMatches && mainActivityMatches && subActivityMatches;
      });
    };

    const mappedMonthOptions = () => uniqueOptions(
      monthOptions.concat(mappings.map((mapping) => mapping.month)).map((month) => makeOption(month, month))
    ).map(optionValue);
    const mappedIcsOptions = () => uniqueOptions(targetRowsForSelection().map((mapping) => makeOption(mapping.ics, mapping.ics))).map(optionValue);
    const mappedMainActivityOptions = () => uniqueOptions(
      targetRowsForSelection({ requireVillage: true, includeMainActivity: false })
        .map((mapping) => makeOption(mapping.main_activity, mapping.main_activity))
    ).map(optionValue);
    const mappedSubActivityOptions = () => {
      const rows = targetRowsForSelection({ requireVillage: true, requireMainActivity: true, includeSubActivity: false });
      const selectedMainActivities = selectedMainActivityValues().map(normalizeOption);
      const configured = activityMappings
        .filter((mapping) => selectedMainActivities.includes(normalizeOption(mapping.main_activity)))
        .flatMap((mapping) => Array(mapping.sub_activities || []));
      const values = rows.flatMap((mapping) => {
        const rawValue = String(mapping.sub_activity || "").trim();
        const matchingConfigured = configured.filter((subActivity) => {
          const normalizedSubActivity = normalizeOption(subActivity);
          return normalizedSubActivity && normalizeOption(rawValue).includes(normalizedSubActivity);
        });
        if (matchingConfigured.length) return matchingConfigured;

        return rawValue.split(/,\s*(?=\d+\.\s*)/).map((value) => value.trim()).filter(Boolean);
      });
      return uniqueOptions(values.map((value) => makeOption(value, value))).map(optionValue);
    };
	    const mappedVillageOptions = () => {
	      const rows = targetRowsForSelection();

	      return uniqueOptions(rows.map((mapping) => makeOption(mapping.village, mapping.village))).map(optionValue);
	    };

    const syncTrainingMonthFromSelection = () => {
      if (!monthSelect || monthSelect.value) return;

      const selectedSubActivities = subActivitySelect
        ? Array.from(subActivitySelect.selectedOptions).map((option) => normalizeOption(option.value)).filter(Boolean)
        : [];
      const rows = targetRowsForSelection({
        requireVillage: true,
        requireMainActivity: true,
        includeSubActivity: false
      }).filter((mapping) => mappingMatchesSelectedSubActivities(mapping, selectedSubActivities));
      const months = uniqueOptions(rows.map((mapping) => makeOption(mapping.month, mapping.month))).map(optionValue);
      if (months.length !== 1) return;

      monthSelect.value = months[0];
      monthSelect.dataset.selectedValue = months[0];
    };

    const selectedTrainingTargetRows = () => {
      syncTrainingMonthFromSelection();

      const selectedVillage = normalizeOption(villageSelect.value);
      const selectedMainActivities = selectedMainActivityValues().map(normalizeOption);
      const selectedSubActivities = subActivitySelect
        ? Array.from(subActivitySelect.selectedOptions).map((option) => normalizeOption(option.value)).filter(Boolean)
        : [];
      if (!monthSelect?.value || !selectedVillage || !selectedMainActivities.length) return [];

      return targetRowsForSelection({ requireMonth: true, requireVillage: true, requireMainActivity: true })
	        .filter((mapping) => mappingMatchesSelectedSubActivities(mapping, selectedSubActivities))
    };

    const targetRowsKey = (rows) => rows
      .map((mapping) => String(mapping.target_mapping_id || ""))
      .filter(Boolean)
      .sort()
      .join(",");

    const mappedFarmers = async () => {
      const rows = selectedTrainingTargetRows();
      if (!rows.length) return [];

      const key = targetRowsKey(rows);
      if (!key) return [];
      if (trainingFarmerCache.has(key)) return trainingFarmerCache.get(key);

      if (!farmersUrl) {
        const farmersById = new Map();
        rows.forEach((mapping) => {
          const includedFarmerIds = new Set((mapping.completed_farmer_ids || []).map(String));
          (mapping.farmers || []).forEach((farmer) => {
            if (!farmer.id) return;
            const farmerId = String(farmer.id);
            const existingFarmer = farmersById.get(farmerId);
            farmersById.set(farmerId, {
              ...farmer,
              already_included: Boolean(existingFarmer?.already_included || includedFarmerIds.has(farmerId))
            });
          });
        });
        const farmers = Array.from(farmersById.values());
        trainingFarmerCache.set(key, farmers);
        return farmers;
      }

      const url = new URL(farmersUrl, window.location.origin);
      url.searchParams.set("target_mapping_ids", key);
      if (selectedFarmerIds.size) {
        url.searchParams.set("existing_farmer_ids", Array.from(selectedFarmerIds).join(","));
      }
      const data = await fetchJson(url.toString());
      const farmers = Array.isArray(data.farmers) ? data.farmers : [];
      trainingFarmerCache.set(key, farmers);
      return farmers;
    };

	    const selectedFarmerBoxes = () => Array.from(formShell.querySelectorAll("[data-training-farmer-checkbox]:checked"));
	    const allFarmerBoxes = () => Array.from(formShell.querySelectorAll("[data-training-farmer-checkbox]"));
	    const farmerBoxes = () => Array.from(formShell.querySelectorAll("[data-training-farmer-checkbox]:not(:disabled)"));
	    const applyTrainingFarmerSearch = () => {
	      if (!farmerList) return;

	      const term = (farmerSearchInput?.value || "").trim().toLowerCase();
	      const items = Array.from(farmerList.querySelectorAll(".vrp-ics-farmer-item"));
	      let visibleCount = 0;
	      items.forEach((item) => {
	        const visible = !term || item.innerText.toLowerCase().includes(term);
	        item.hidden = !visible;
	        if (visible) visibleCount += 1;
	      });
	      if (farmerSearchEmpty) farmerSearchEmpty.hidden = visibleCount > 0 || !items.length;
	    };
	    const numberValue = (input) => Number(input?.value || 0);

    const syncTotalFarmerCount = () => {
	      if (!totalFarmerCountInput) return;

	      const total = numberValue(maleCountInput) + numberValue(femaleCountInput);
	      totalFarmerCountInput.value = total ? String(total) : "";
	    };

    const syncIcsFarmerCountSplit = () => {
      if (!icsSelect?.value || !maleCountInput || !femaleCountInput) return;

      const count = selectedFarmerBoxes().length;
      maleCountInput.value = "0";
      femaleCountInput.value = String(count);
    };

	    const updateFarmerCount = () => {
	      const count = selectedFarmerBoxes().length;
	      const boxes = farmerBoxes();
	      const mappedCount = allFarmerBoxes().length;
	      const completedCount = farmerList.querySelectorAll(".already-included").length;
      if (farmerCount) farmerCount.textContent = `${count} selected / ${mappedCount} mapped farmers • ${completedCount} completed • ${mappedCount - completedCount} pending`;
	      if (farmerCountInput) farmerCountInput.value = String(count);
	      if (farmerSelectAll) {
	        farmerSelectAll.checked = boxes.length > 0 && count === boxes.length;
	        farmerSelectAll.indeterminate = count > 0 && count < boxes.length;
	        farmerSelectAll.disabled = boxes.length === 0;
	      }
	      if (farmerSelectAllButton) {
	        farmerSelectAllButton.disabled = boxes.length === 0;
	        farmerSelectAllButton.textContent = boxes.length > 0 && count === boxes.length ? "Clear all" : "Select all";
	      }
      syncIcsFarmerCountSplit();
	      syncTotalFarmerCount();
	      validateTrainingCountSplit(false);
	    };

	    const validateTrainingCountSplit = (report = false) => {
	      syncTotalFarmerCount();
	      [farmerCountInput, totalFarmerCountInput, maleCountInput, femaleCountInput].forEach((input) => input?.setCustomValidity(""));

	      const maleBlank = !maleCountInput?.value;
	      const femaleBlank = !femaleCountInput?.value;
	      const maleCountValue = Number(maleCountInput?.value || 0);
	      const femaleCountValue = Number(femaleCountInput?.value || 0);
	      let invalidInput = null;
	      let message = "";

	      if (Number(farmerCountInput?.value || 0) <= 0) {
	        invalidInput = farmerCountInput;
	        message = "Target Farmers select karein.";
	      } else if (maleBlank) {
	        invalidInput = maleCountInput;
	        message = "Male Count required hai.";
	      } else if (femaleBlank) {
	        invalidInput = femaleCountInput;
	        message = "Female Count required hai.";
	      } else if (maleCountValue < 0) {
	        invalidInput = maleCountInput;
	        message = "Male Count 0 se kam nahi ho sakta.";
	      } else if (femaleCountValue < 0) {
	        invalidInput = femaleCountInput;
	        message = "Female Count 0 se kam nahi ho sakta.";
	      }

	      if (!invalidInput) return true;

	      invalidInput?.setCustomValidity(message);
	      if (report) invalidInput?.reportValidity();
	      return false;
	    };

	    const renderTrainingFarmers = async () => {
	      if (!farmerList) return;
	      if (farmerSearchEmpty) farmerSearchEmpty.hidden = true;
      const targetRows = selectedTrainingTargetRows();
      const loadKey = targetRowsKey(targetRows);

	      if (monthSelect && !monthSelect.value) {
	        farmerList.textContent = "Select Month to load target farmers.";
	        if (farmerSelectAll) farmerSelectAll.checked = false;
	        updateFarmerCount();
	        return;
	      }

	      if (!villageSelect.value) {
	        farmerList.textContent = "Select Village Name to load target farmers.";
	        if (farmerSelectAll) farmerSelectAll.checked = false;
	        updateFarmerCount();
	        return;
	      }

      if (mainActivityTypeSelect && !mainActivityTypeSelect.value) {
        farmerList.textContent = "Select Main Activity Type to load target farmers.";
        if (farmerSelectAll) farmerSelectAll.checked = false;
        updateFarmerCount();
        return;
      }

      if (!selectedMainActivityValues().length) {
        farmerList.textContent = "Select Main Activity to load target farmers.";
        if (farmerSelectAll) farmerSelectAll.checked = false;
        updateFarmerCount();
        return;
      }

      const selectedSubActivityCount = subActivitySelect
        ? Array.from(subActivitySelect.selectedOptions).filter((option) => option.value).length
        : 0;
      if (selectedMainActivityValues().length && !selectedSubActivityCount) {
        farmerList.textContent = "Select Sub Activity to narrow the target farmers.";
      }

      if (!targetRows.length) {
        farmerList.textContent = "No target farmers found for selected activity.";
        if (farmerSelectAll) farmerSelectAll.checked = false;
        updateFarmerCount();
        return;
      }

      activeFarmerLoadKey = loadKey;
      farmerList.textContent = "Loading target farmers...";
      let farmers = [];
      try {
        farmers = await mappedFarmers();
      } catch (_error) {
        if (activeFarmerLoadKey === loadKey) {
          farmerList.textContent = "Target farmers load failed. Please try again.";
          updateFarmerCount();
        }
        return;
      }
      if (activeFarmerLoadKey !== loadKey) return;

      if (!farmers.length) {
        farmerList.textContent = "No target farmers found for selected activity.";
        if (farmerSelectAll) farmerSelectAll.checked = false;
	        updateFarmerCount();
	        return;
	      }

	      farmerList.innerHTML = farmers.map((farmer) => {
	        const meta = [
	          farmer.father_name ? `Father: ${farmer.father_name}` : "",
	          farmer.tracenet_no ? `Tracenet: ${farmer.tracenet_no}` : "",
	          farmer.mobile_no ? `Mobile: ${farmer.mobile_no}` : "",
	          farmer.khasara_no ? `Khasara: ${farmer.khasara_no}` : ""
	        ].filter(Boolean).join(" | ");
	        const isSelected = selectedFarmerIds.has(String(farmer.id));
	        const checked = isSelected ? " checked" : "";
	        const includedClass = farmer.already_included ? " already-included" : "";
	        const includedBadge = farmer.already_included ? '<b class="training-included-badge">Already Completed</b>' : "";
	        return `
	          <label class="vrp-ics-farmer-item${includedClass}">
	            <input type="checkbox" name="module_record[selected_farmer_ids][]" value="${escapeHtml(farmer.id)}" data-training-farmer-checkbox${checked}>
	            <span>
	              <strong>${escapeHtml(farmer.farmer_name || `Farmer #${farmer.id}`)} ${includedBadge}</strong>
	              <small>${escapeHtml(meta)}</small>
	            </span>
	          </label>
	        `;
	      }).join("");
	      applyTrainingFarmerSearch();

	      farmerList.querySelectorAll("[data-training-farmer-checkbox]").forEach((checkbox) => {
	        checkbox.addEventListener("change", () => {
	          if (checkbox.checked) {
	            selectedFarmerIds.add(String(checkbox.value));
	          } else {
	            selectedFarmerIds.delete(String(checkbox.value));
	          }
	          updateFarmerCount();
	        });
	      });
	      updateFarmerCount();
	    };

	    farmerSearchInput?.addEventListener("input", applyTrainingFarmerSearch);

	    farmerSelectAll?.addEventListener("change", () => {
	      farmerBoxes().forEach((checkbox) => {
	        checkbox.checked = farmerSelectAll.checked;
	        if (checkbox.checked) {
	          selectedFarmerIds.add(String(checkbox.value));
	        } else {
	          selectedFarmerIds.delete(String(checkbox.value));
	        }
	      });
	      updateFarmerCount();
	    });

	    farmerSelectAllButton?.addEventListener("click", () => {
	      const boxes = farmerBoxes();
	      const shouldSelect = selectedFarmerBoxes().length !== boxes.length;
	      boxes.forEach((checkbox) => {
	        checkbox.checked = shouldSelect;
	        if (shouldSelect) {
	          selectedFarmerIds.add(String(checkbox.value));
	        } else {
	          selectedFarmerIds.delete(String(checkbox.value));
	        }
	      });
	      updateFarmerCount();
	    });

	    if (monthSelect) fillTrainingSelect(monthSelect, mappedMonthOptions(), "Select Month");
	    const initialIcsOptions = mappedIcsOptions();
	    fillTrainingSelect(icsSelect, initialIcsOptions, "Select ICS Name");
	    setOnlyTrainingOption(icsSelect, initialIcsOptions);
	    const initialVillageOptions = mappedVillageOptions();
	    fillTrainingSelect(villageSelect, initialVillageOptions, "Select Village Name");
	    setOnlyTrainingOption(villageSelect, initialVillageOptions);
	    const initialMainOptions = mappedMainActivityOptions();
	    if (mainActivitySelect) fillTrainingSelect(mainActivitySelect, initialMainOptions, "Select Main Activity");
	    if (!selectedMainActivityValues().length) autoSelectMappedMainActivities();
	    else renderMainActivityChips();
	    const initialSubOptions = mappedSubActivityOptions();
	    if (subActivitySelect) fillTrainingSelect(subActivitySelect, initialSubOptions, "Select Sub Activity");
	    if (selectedSubActivityValues().length) renderSubActivityChips(); else autoSelectMappedSubActivities();
	    renderTrainingFarmers();

	    if (geoLatitudeInput && geoLongitudeInput && navigator.geolocation) {
	      navigator.geolocation.getCurrentPosition((position) => {
	        geoLatitudeInput.value = position.coords.latitude || "";
	        geoLongitudeInput.value = position.coords.longitude || "";
	      });
	    }

	    const resetTrainingTargetAfterMonth = () => {
	      icsSelect.dataset.selectedValue = "";
	      villageSelect.dataset.selectedValue = "";
	      icsSelect.value = "";
	      villageSelect.value = "";
	      if (mainActivitySelect) mainActivitySelect.dataset.selectedValue = "";
	      if (subActivitySelect) subActivitySelect.dataset.selectedValues = "[]";
	      if (mainActivitySelect) mainActivitySelect.value = "";
	      if (subActivitySelect) subActivitySelect.value = "";
	      const icsOptions = mappedIcsOptions();
	      fillTrainingSelect(icsSelect, icsOptions, "Select ICS Name");
	      setOnlyTrainingOption(icsSelect, icsOptions);
	      const villageOptions = mappedVillageOptions();
	      fillTrainingSelect(villageSelect, villageOptions, "Select Village Name");
	      setOnlyTrainingOption(villageSelect, villageOptions);
	      const mainOptions = mappedMainActivityOptions();
	      if (mainActivitySelect) fillTrainingSelect(mainActivitySelect, mainOptions, "Select Main Activity");
	      autoSelectMappedMainActivities();
	      const subOptions = mappedSubActivityOptions();
	      if (subActivitySelect) fillTrainingSelect(subActivitySelect, subOptions, "Select Sub Activity");
	      autoSelectMappedSubActivities();
	      selectedFarmerIds.clear();
	      renderTrainingFarmers();
	    };

	    monthSelect?.addEventListener("change", resetTrainingTargetAfterMonth);

	    icsSelect.addEventListener("change", () => {
	      villageSelect.dataset.selectedValue = "";
	      villageSelect.value = "";
	      if (mainActivitySelect) mainActivitySelect.dataset.selectedValue = "";
	      if (subActivitySelect) subActivitySelect.dataset.selectedValues = "[]";
	      if (mainActivitySelect) mainActivitySelect.value = "";
	      if (subActivitySelect) subActivitySelect.value = "";
	      const villageOptions = mappedVillageOptions();
	      fillTrainingSelect(villageSelect, villageOptions, "Select Village Name");
	      setOnlyTrainingOption(villageSelect, villageOptions);
	      const mainOptions = mappedMainActivityOptions();
	      if (mainActivitySelect) fillTrainingSelect(mainActivitySelect, mainOptions, "Select Main Activity");
	      autoSelectMappedMainActivities();
	      const subOptions = mappedSubActivityOptions();
	      if (subActivitySelect) fillTrainingSelect(subActivitySelect, subOptions, "Select Sub Activity");
	      autoSelectMappedSubActivities();
	      selectedFarmerIds.clear();
	      renderTrainingFarmers();
	    });
	    villageSelect.addEventListener("change", () => {
	      if (mainActivitySelect) mainActivitySelect.dataset.selectedValue = "";
	      if (subActivitySelect) subActivitySelect.dataset.selectedValues = "[]";
	      if (mainActivitySelect) mainActivitySelect.value = "";
	      if (subActivitySelect) subActivitySelect.value = "";
	      const mainOptions = mappedMainActivityOptions();
	      if (mainActivitySelect) fillTrainingSelect(mainActivitySelect, mainOptions, "Select Main Activity");
	      autoSelectMappedMainActivities();
	      const subOptions = mappedSubActivityOptions();
	      if (subActivitySelect) fillTrainingSelect(subActivitySelect, subOptions, "Select Sub Activity");
	      autoSelectMappedSubActivities();
	      selectedFarmerIds.clear();
	      renderTrainingFarmers();
	    });
	    mainActivityTypeSelect?.addEventListener("change", () => {
	      if (mainActivitySelect) mainActivitySelect.dataset.selectedValue = "";
	      if (subActivitySelect) subActivitySelect.dataset.selectedValues = "[]";
	      if (mainActivitySelect) mainActivitySelect.value = "";
	      if (subActivitySelect) subActivitySelect.value = "";
	      const mainOptions = mappedMainActivityOptions();
	      if (mainActivitySelect) fillTrainingSelect(mainActivitySelect, mainOptions, "Select Main Activity");
	      autoSelectMappedMainActivities();
	      const subOptions = mappedSubActivityOptions();
	      if (subActivitySelect) fillTrainingSelect(subActivitySelect, subOptions, "Select Sub Activity");
	      autoSelectMappedSubActivities();
	      selectedFarmerIds.clear();
	      renderTrainingFarmers();
	    });
	    mainActivitySelect?.addEventListener("change", () => {
	      mainActivitySelect.dataset.selectedValues = JSON.stringify(selectedMainActivityValues());
	      renderMainActivityChips();
	      if (subActivitySelect) subActivitySelect.dataset.selectedValues = "[]";
	      if (subActivitySelect) subActivitySelect.value = "";
	      if (subActivitySelect) {
	        fillTrainingSelect(subActivitySelect, mappedSubActivityOptions(), "Select Sub Activity");
	        autoSelectMappedSubActivities();
	      }
	      selectedFarmerIds.clear();
	      renderTrainingFarmers();
	    });
	    subActivitySelect?.addEventListener("change", () => {
	      subActivitySelect.dataset.selectedValues = JSON.stringify(selectedSubActivityValues());
	      renderSubActivityChips();
	      selectedFarmerIds.clear();
	      renderTrainingFarmers();
	    });

    [maleCountInput, femaleCountInput].forEach((input) => {
      input?.addEventListener("input", () => {
        updateFarmerCount();
        validateTrainingCountSplit(false);
      });
      input?.addEventListener("change", () => {
        updateFarmerCount();
        validateTrainingCountSplit(false);
      });
    });

    formShell.querySelector("form")?.addEventListener("submit", (event) => {
      if (validateTrainingCountSplit(true)) return;

      event.preventDefault();
    });
	  });

  document.querySelectorAll("[data-seed-target-form]").forEach((formShell) => {
    let mappings = [];
    let monthOptions = [];
    let currentVrpOption = null;
    try {
      mappings = JSON.parse(formShell.dataset.seedTargetMap || "[]");
    } catch (_error) {
      mappings = [];
    }
    try {
      monthOptions = JSON.parse(formShell.dataset.seedMonthOptions || "[]");
    } catch (_error) {
      monthOptions = [];
    }
    try {
      currentVrpOption = JSON.parse(formShell.dataset.seedCurrentVrpOption || "null");
    } catch (_error) {
      currentVrpOption = null;
    }

    const vrpSelect = formShell.querySelector("[data-seed-target-vrp]");
    const monthSelect = formShell.querySelector("[data-seed-target-month]");
    const icsSelect = formShell.querySelector("[data-seed-target-ics]");
    const villageSelect = formShell.querySelector("[data-seed-target-village]");
    const topicSelect = formShell.querySelector("[data-seed-target-topic]");
    const subjectSelect = formShell.querySelector("[data-seed-target-subject]");
    const targetInput = formShell.querySelector("[data-seed-target-quantity]");
    const targetIdInput = formShell.querySelector("[data-seed-target-id]");
    const vrpIdInput = formShell.querySelector("[data-seed-vrp-id]");
    const contactInput = formShell.querySelector("[data-seed-vrp-contact]");
    const departmentInput = formShell.querySelector("[data-seed-vrp-department]");
    const achievementInput = formShell.querySelector("[data-seed-achievement]");
    const farmerPanel = formShell.querySelector("[data-seed-farmer-panel]");
    const farmerList = formShell.querySelector("[data-seed-farmer-list]");
    const farmerSelectAll = formShell.querySelector("[data-seed-farmer-select-all]");
    const farmerSelectAllButton = formShell.querySelector("[data-seed-farmer-select-all-button]");
    const farmerCountLabel = formShell.querySelector("[data-seed-farmer-count]");
    const farmerCountInput = formShell.querySelector("[data-seed-farmer-count-input]");
    const farmerSearchInput = formShell.querySelector("[data-seed-farmer-search]");
    const farmerSearchEmpty = formShell.querySelector("[data-seed-farmer-search-empty]");
    if (!vrpSelect || !monthSelect || !icsSelect || !villageSelect || !topicSelect || !subjectSelect) return;
    const selectedSeedFarmerIds = new Set(JSON.parse(farmerPanel?.dataset.selectedFarmerIds || "[]").map(String));
    const seedFarmersUrl = formShell.dataset.seedFarmersUrl;
    const seedFarmerCache = new Map();
    let activeSeedFarmerKey = "";

    const escapeSeedHtml = (value) => String(value || "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");

    const selectOption = (option, optionData, selected) => {
      const value = optionValue(optionData);
      const label = optionLabel(optionData);
      option.selected = normalizeOption(value) === normalizeOption(selected) ||
        normalizeOption(label) === normalizeOption(selected);
    };

    const fillSeedSelect = (select, options, placeholder) => {
      const selected = select.dataset.selectedValue || select.value;
      select.innerHTML = "";

      const blank = document.createElement("option");
      blank.value = "";
      blank.textContent = options.length ? placeholder : `No ${placeholder.replace(/^Select\s+/i, "")} saved yet`;
      select.appendChild(blank);

      options.forEach((optionData) => {
        const option = document.createElement("option");
        option.value = optionValue(optionData);
        option.textContent = optionLabel(optionData);
        selectOption(option, optionData, selected);
        select.appendChild(option);
      });
    };

    const setOnlySeedOption = (select, options) => {
      if (!select || select.value || options.length !== 1) return;

      select.value = optionValue(options[0]);
      select.dataset.selectedValue = select.value;
    };

    const rowsForSelection = ({
      requireMonth = false,
      requireIcs = false,
      requireVillage = false,
      requireTopic = false,
      includeVrp = true,
      includeSubject = true
    } = {}) => {
      const selectedVrp = includeVrp ? normalizeOption(vrpSelect.value) : "";
      const selectedMonth = normalizeOption(monthSelect.value);
      const selectedIcs = normalizeOption(icsSelect.value);
      const selectedVillage = normalizeOption(villageSelect.value);
      const selectedTopic = normalizeOption(topicSelect.value);
      const selectedSubject = includeSubject ? normalizeOption(subjectSelect.value) : "";

      if (requireMonth && !selectedMonth) return [];
      if (requireIcs && !selectedIcs) return [];
      if (requireVillage && !selectedVillage) return [];
      if (requireTopic && !selectedTopic) return [];

      return mappings.filter((mapping) => {
        const vrpMatches = !selectedVrp ||
          normalizeOption(mapping.vrp_id) === selectedVrp ||
          normalizeOption(mapping.jeevika_jankar_name) === selectedVrp;
        const monthMatches = !selectedMonth || normalizeOption(mapping.month) === selectedMonth;
        const icsMatches = !selectedIcs || normalizeOption(mapping.ics) === selectedIcs;
        const villageMatches = !selectedVillage || normalizeOption(mapping.village) === selectedVillage;
        const topicMatches = !selectedTopic || normalizeOption(mapping.training_topic) === selectedTopic;
        const subjectMatches = !selectedSubject || normalizeOption(mapping.training_subject) === selectedSubject;
        return vrpMatches && monthMatches && icsMatches && villageMatches && topicMatches && subjectMatches;
      });
    };

    const vrpValues = () => uniqueOptions(
      (currentVrpOption ? [currentVrpOption] : []).concat(mappings.map((mapping) => ({
        value: mapping.vrp_id || mapping.jeevika_jankar_name,
        label: mapping.jeevika_jankar_name || mapping.vrp_id
      })))
    );
    const monthValues = () => uniqueOptions(
      monthOptions.concat(rowsForSelection({ includeVrp: true }).map((mapping) => mapping.month)).map((month) => makeOption(month, month))
    ).map(optionValue);
    const icsValues = () => uniqueOptions(rowsForSelection().map((mapping) => makeOption(mapping.ics, mapping.ics))).map(optionValue);
    const villageValues = () => uniqueOptions(rowsForSelection({ requireIcs: true }).map((mapping) => makeOption(mapping.village, mapping.village))).map(optionValue);
    const topicValues = () => uniqueOptions(rowsForSelection({ requireIcs: true, requireVillage: true }).map((mapping) => makeOption(mapping.training_topic, mapping.training_topic))).map(optionValue);
    const subjectValues = () => uniqueOptions(rowsForSelection({ requireIcs: true, requireVillage: true, requireTopic: true, includeSubject: false }).map((mapping) => makeOption(mapping.training_subject, mapping.training_subject))).map(optionValue);

    const selectedSeedMapping = () => rowsForSelection({
      requireIcs: true,
      requireVillage: true,
      requireTopic: true
    }).find((mapping) => normalizeOption(mapping.training_subject) === normalizeOption(subjectSelect.value));

    const selectedSeedMappingIsManual = () => Boolean(selectedSeedMapping()?.new_farmer_target);

    const syncSeedMonthFromSelection = () => {
      if (monthSelect.value) return;

      const mapping = selectedSeedMapping();
      if (!mapping?.month) return;

      monthSelect.value = mapping.month;
      monthSelect.dataset.selectedValue = mapping.month;
    };

    const selectedVrpMapping = () => rowsForSelection({}).find((mapping) => {
      const selectedVrp = normalizeOption(vrpSelect.value);
      return selectedVrp && (
        normalizeOption(mapping.vrp_id) === selectedVrp ||
        normalizeOption(mapping.jeevika_jankar_name) === selectedVrp
      );
    }) || mappings.find((mapping) => {
      const selectedVrp = normalizeOption(vrpSelect.value);
      return selectedVrp && (
        normalizeOption(mapping.vrp_id) === selectedVrp ||
        normalizeOption(mapping.jeevika_jankar_name) === selectedVrp
      );
    });

    const refreshVrpDetails = () => {
      const mapping = selectedSeedMapping() || selectedVrpMapping();
      const fallbackMatches = currentVrpOption && (
        normalizeOption(currentVrpOption.value) === normalizeOption(vrpSelect.value) ||
        normalizeOption(currentVrpOption.label) === normalizeOption(vrpSelect.value)
      );
      const fallback = fallbackMatches ? currentVrpOption : {};
      if (contactInput) contactInput.value = String(mapping?.contact_number || fallback.contact_number || "").replace(/\D/g, "").slice(-10);
      if (departmentInput) departmentInput.value = mapping?.department || fallback.department || "";
      if (vrpIdInput) vrpIdInput.value = mapping?.vrp_id || fallback.value || vrpSelect.value || "";
    };

    const seedFarmerBoxes = () => Array.from(formShell.querySelectorAll("[data-seed-farmer-checkbox]"));
    const selectedSeedFarmerBoxes = () => seedFarmerBoxes().filter((checkbox) => checkbox.checked);
    const seedFarmerSearchTerm = () => (farmerSearchInput?.value || "").trim().toLowerCase();

    const applySeedFarmerSearch = () => {
      if (!farmerList) return;

      const term = seedFarmerSearchTerm();
      const items = Array.from(farmerList.querySelectorAll(".vrp-ics-farmer-item"));
      let visibleCount = 0;

      items.forEach((item) => {
        const text = item.innerText.toLowerCase();
        const visible = !term || text.includes(term);
        item.hidden = !visible;
        if (visible) visibleCount += 1;
      });

      if (farmerSearchEmpty) farmerSearchEmpty.hidden = visibleCount > 0 || !items.length;
    };

    const updateSeedFarmerCount = () => {
      const count = selectedSeedFarmerBoxes().length;
      const boxes = seedFarmerBoxes().filter((checkbox) => !checkbox.disabled);
      if (farmerCountLabel) farmerCountLabel.textContent = `${count} farmer selected`;
      if (farmerCountInput) farmerCountInput.value = selectedSeedMappingIsManual() ? "0" : (count ? String(count) : "");
      if (farmerSelectAll) {
        farmerSelectAll.checked = !selectedSeedMappingIsManual() && boxes.length > 0 && boxes.every((checkbox) => checkbox.checked);
        farmerSelectAll.indeterminate = !selectedSeedMappingIsManual() && boxes.some((checkbox) => checkbox.checked) && !farmerSelectAll.checked;
        farmerSelectAll.disabled = selectedSeedMappingIsManual() || boxes.length === 0;
      }
      if (farmerSelectAllButton) {
        farmerSelectAllButton.disabled = selectedSeedMappingIsManual() || boxes.length === 0;
        farmerSelectAllButton.textContent = boxes.length > 0 && boxes.every((checkbox) => checkbox.checked) ? "Clear all" : "Select all";
      }
    };

    const seedFarmersForMapping = async (mapping) => {
      const targetId = String(mapping?.target_mapping_id || "");
      if (!targetId) return { farmers: mapping?.farmers || [], completedFarmerIds: mapping?.completed_farmer_ids || [] };
      if (seedFarmerCache.has(targetId)) return seedFarmerCache.get(targetId);
      if ((mapping.farmers || []).length || !seedFarmersUrl) {
        const cached = { farmers: mapping.farmers || [], completedFarmerIds: mapping.completed_farmer_ids || [] };
        seedFarmerCache.set(targetId, cached);
        return cached;
      }

      const url = new URL(seedFarmersUrl, window.location.origin);
      url.searchParams.set("target_mapping_id", targetId);
      const data = await fetchJson(url.toString());
      const cached = {
        farmers: Array.isArray(data.farmers) ? data.farmers : [],
        completedFarmerIds: Array.isArray(data.completed_farmer_ids) ? data.completed_farmer_ids : []
      };
      seedFarmerCache.set(targetId, cached);
      return cached;
    };

    const renderSeedFarmers = async () => {
      if (!farmerList) return;

      const mapping = selectedSeedMapping();
      if (!mapping) {
        farmerList.textContent = "Select Village and Activity to load mapped farmers.";
        if (farmerSearchEmpty) farmerSearchEmpty.hidden = true;
        updateSeedFarmerCount();
        return;
      }

      if (mapping.new_farmer_target) {
        farmerList.textContent = "New Farmer Target saved without mapped farmers.";
        if (farmerSearchEmpty) farmerSearchEmpty.hidden = true;
        selectedSeedFarmerIds.clear();
        updateSeedFarmerCount();
        return;
      }

      const loadKey = String(mapping.target_mapping_id || "");
      activeSeedFarmerKey = loadKey;
      farmerList.textContent = "Loading mapped farmers...";
      let loadedData = { farmers: [], completedFarmerIds: [] };
      try {
        loadedData = await seedFarmersForMapping(mapping);
      } catch (_error) {
        if (activeSeedFarmerKey === loadKey) {
          farmerList.textContent = "Mapped farmers load failed. Please try again.";
          if (farmerSearchEmpty) farmerSearchEmpty.hidden = true;
          updateSeedFarmerCount();
        }
        return;
      }
      if (activeSeedFarmerKey !== loadKey) return;

      const farmers = loadedData.farmers || [];
      const completedFarmerIds = new Set((loadedData.completedFarmerIds || []).map(String));
      if (!farmers.length) {
        farmerList.textContent = "No mapped farmers found for selected activity.";
        if (farmerSearchEmpty) farmerSearchEmpty.hidden = true;
        updateSeedFarmerCount();
        return;
      }

      const farmerRows = farmers.map((farmer, index) => {
        const farmerId = String(farmer.id || "");
        return {
          farmer,
          farmerId,
          index,
          completed: completedFarmerIds.has(farmerId) && !selectedSeedFarmerIds.has(farmerId),
          checked: selectedSeedFarmerIds.has(farmerId)
        };
      }).sort((a, b) => {
        if (a.completed !== b.completed) return a.completed ? 1 : -1;
        return a.index - b.index;
      });

      farmerList.innerHTML = farmerRows.map(({ farmer, farmerId, completed, checked: isChecked }) => {
        const checked = isChecked ? " checked" : "";
        const disabled = completed ? " disabled" : "";
        const meta = [
          farmer.father_name ? `Father: ${farmer.father_name}` : "",
          farmer.tracenet_no ? `Tracenet: ${farmer.tracenet_no}` : "",
          farmer.mobile_no ? `Mobile: ${farmer.mobile_no}` : "",
          farmer.khasara_no ? `Khasara: ${farmer.khasara_no}` : "",
          completed ? "Already submitted" : ""
        ].filter(Boolean).join(" | ");

        return `
          <label class="vrp-ics-farmer-item${completed ? " disabled" : ""}">
            <input type="checkbox" name="module_record[selected_farmer_ids][]" value="${escapeSeedHtml(farmerId)}" data-seed-farmer-checkbox${checked}${disabled}>
            <span>
              <strong>${escapeSeedHtml(farmer.farmer_name || `Farmer #${farmerId}`)}</strong>
              <small>${escapeSeedHtml(meta)}</small>
            </span>
          </label>
        `;
      }).join("");
      applySeedFarmerSearch();

      farmerList.querySelectorAll("[data-seed-farmer-checkbox]").forEach((checkbox) => {
        checkbox.addEventListener("change", () => {
          if (checkbox.checked) {
            selectedSeedFarmerIds.add(String(checkbox.value));
          } else {
            selectedSeedFarmerIds.delete(String(checkbox.value));
          }
          updateSeedFarmerCount();
          validateSeedTargetForm(false);
        });
      });
      updateSeedFarmerCount();
    };

    const refreshTarget = () => {
      syncSeedMonthFromSelection();
      const mapping = selectedSeedMapping();
      if (targetInput) targetInput.value = mapping?.target || "";
      if (targetIdInput) targetIdInput.value = mapping?.target_mapping_id || "";
      refreshVrpDetails();
      if (achievementInput && targetInput?.value) {
        achievementInput.max = targetInput.value;
      } else if (achievementInput) {
        achievementInput.removeAttribute("max");
      }
      renderSeedFarmers();
    };

    const resetAfter = (selects) => {
      selects.forEach((select) => {
        select.dataset.selectedValue = "";
        select.value = "";
      });
      selectedSeedFarmerIds.clear();
      refreshTarget();
    };

    fillSeedSelect(vrpSelect, vrpValues(), "Select Jeevika Jankar Name");
    if (!vrpSelect.value && vrpSelect.options.length === 2) {
      vrpSelect.selectedIndex = 1;
      vrpSelect.dataset.selectedValue = vrpSelect.value;
    }
    fillSeedSelect(monthSelect, monthValues(), "Select Month");
    const initialIcsOptions = icsValues();
    fillSeedSelect(icsSelect, initialIcsOptions, "Select ICS");
    setOnlySeedOption(icsSelect, initialIcsOptions);
    const initialVillageOptions = villageValues();
    fillSeedSelect(villageSelect, initialVillageOptions, "Select Village");
    setOnlySeedOption(villageSelect, initialVillageOptions);
    const initialTopicOptions = topicValues();
    fillSeedSelect(topicSelect, initialTopicOptions, "Select Main Activity");
    setOnlySeedOption(topicSelect, initialTopicOptions);
    const initialSubjectOptions = subjectValues();
    fillSeedSelect(subjectSelect, initialSubjectOptions, "Select Sub Activity");
    setOnlySeedOption(subjectSelect, initialSubjectOptions);
    refreshTarget();

    vrpSelect.addEventListener("change", () => {
      resetAfter([monthSelect, icsSelect, villageSelect, topicSelect, subjectSelect]);
      refreshVrpDetails();
      fillSeedSelect(monthSelect, monthValues(), "Select Month");
      const icsOptions = icsValues();
      fillSeedSelect(icsSelect, icsOptions, "Select ICS");
      setOnlySeedOption(icsSelect, icsOptions);
      const villageOptions = villageValues();
      fillSeedSelect(villageSelect, villageOptions, "Select Village");
      setOnlySeedOption(villageSelect, villageOptions);
      const topicOptions = topicValues();
      fillSeedSelect(topicSelect, topicOptions, "Select Main Activity");
      setOnlySeedOption(topicSelect, topicOptions);
      const subjectOptions = subjectValues();
      fillSeedSelect(subjectSelect, subjectOptions, "Select Sub Activity");
      setOnlySeedOption(subjectSelect, subjectOptions);
      refreshTarget();
    });
    monthSelect.addEventListener("change", () => {
      resetAfter([icsSelect, villageSelect, topicSelect, subjectSelect]);
      const icsOptions = icsValues();
      fillSeedSelect(icsSelect, icsOptions, "Select ICS");
      setOnlySeedOption(icsSelect, icsOptions);
      const villageOptions = villageValues();
      fillSeedSelect(villageSelect, villageOptions, "Select Village");
      setOnlySeedOption(villageSelect, villageOptions);
      const topicOptions = topicValues();
      fillSeedSelect(topicSelect, topicOptions, "Select Main Activity");
      setOnlySeedOption(topicSelect, topicOptions);
      const subjectOptions = subjectValues();
      fillSeedSelect(subjectSelect, subjectOptions, "Select Sub Activity");
      setOnlySeedOption(subjectSelect, subjectOptions);
      refreshTarget();
    });
    icsSelect.addEventListener("change", () => {
      resetAfter([villageSelect, topicSelect, subjectSelect]);
      const villageOptions = villageValues();
      fillSeedSelect(villageSelect, villageOptions, "Select Village");
      setOnlySeedOption(villageSelect, villageOptions);
      const topicOptions = topicValues();
      fillSeedSelect(topicSelect, topicOptions, "Select Main Activity");
      setOnlySeedOption(topicSelect, topicOptions);
      const subjectOptions = subjectValues();
      fillSeedSelect(subjectSelect, subjectOptions, "Select Sub Activity");
      setOnlySeedOption(subjectSelect, subjectOptions);
      refreshTarget();
    });
    villageSelect.addEventListener("change", () => {
      resetAfter([topicSelect, subjectSelect]);
      const topicOptions = topicValues();
      fillSeedSelect(topicSelect, topicOptions, "Select Main Activity");
      setOnlySeedOption(topicSelect, topicOptions);
      const subjectOptions = subjectValues();
      fillSeedSelect(subjectSelect, subjectOptions, "Select Sub Activity");
      setOnlySeedOption(subjectSelect, subjectOptions);
      refreshTarget();
    });
    topicSelect.addEventListener("change", () => {
      resetAfter([subjectSelect]);
      const subjectOptions = subjectValues();
      fillSeedSelect(subjectSelect, subjectOptions, "Select Sub Activity");
      setOnlySeedOption(subjectSelect, subjectOptions);
      refreshTarget();
    });
    subjectSelect.addEventListener("change", () => {
      selectedSeedFarmerIds.clear();
      refreshTarget();
    });

    farmerSearchInput?.addEventListener("input", applySeedFarmerSearch);

    farmerSelectAll?.addEventListener("change", () => {
      seedFarmerBoxes().filter((checkbox) => !checkbox.disabled).forEach((checkbox) => {
        checkbox.checked = farmerSelectAll.checked;
        if (checkbox.checked) {
          selectedSeedFarmerIds.add(String(checkbox.value));
        } else {
          selectedSeedFarmerIds.delete(String(checkbox.value));
        }
      });
      updateSeedFarmerCount();
      validateSeedTargetForm(false);
    });

    farmerSelectAllButton?.addEventListener("click", () => {
      const boxes = seedFarmerBoxes().filter((checkbox) => !checkbox.disabled);
      const shouldSelect = !boxes.length ? false : boxes.some((checkbox) => !checkbox.checked);
      boxes.forEach((checkbox) => {
        checkbox.checked = shouldSelect;
        if (shouldSelect) {
          selectedSeedFarmerIds.add(String(checkbox.value));
        } else {
          selectedSeedFarmerIds.delete(String(checkbox.value));
        }
      });
      updateSeedFarmerCount();
      validateSeedTargetForm(false);
    });

    const validateSeedTargetForm = (report = false) => {
      [vrpSelect, monthSelect, icsSelect, villageSelect, topicSelect, subjectSelect, contactInput, farmerCountInput, targetInput, achievementInput].forEach((input) => {
        input?.setCustomValidity("");
      });

      const mapping = selectedSeedMapping();
      const contactDigits = String(contactInput?.value || "").replace(/\D/g, "");
      const selectedFarmerCount = selectedSeedFarmerBoxes().length;
      const farmerCountValue = Number(farmerCountInput?.value || 0);
      const targetValue = Number(targetInput?.value || 0);
      const achievementValue = Number(achievementInput?.value || 0);
      const manualTarget = Boolean(mapping?.new_farmer_target);
      let invalidInput = null;
      let message = "";

      if (!mapping) {
        invalidInput = subjectSelect;
        message = "Mapped Other activity target select karein.";
      } else if (contactInput && contactDigits.length !== 10) {
        invalidInput = contactInput;
        message = "Contact Number valid 10 digit hona chahiye.";
      } else if (farmerPanel && !manualTarget && selectedFarmerCount <= 0) {
        invalidInput = farmerCountInput || subjectSelect;
        message = "Mapped Farmers select karein.";
      } else if (farmerPanel && farmerCountInput && !manualTarget && farmerCountValue !== selectedFarmerCount) {
        invalidInput = farmerCountInput;
        message = "Farmer Count selected farmers ke count ke equal hona chahiye.";
      } else if (farmerPanel && farmerCountInput && !manualTarget && farmerCountValue > targetValue) {
        invalidInput = farmerCountInput;
        message = `Farmer Count Target (${targetValue}) se jyada nahi ho sakta.`;
      } else if (!targetInput?.value || targetValue < 0) {
        invalidInput = targetInput;
        message = "Mapped Target valid hona chahiye.";
      } else if (!achievementInput?.value || achievementValue < 0) {
        invalidInput = achievementInput;
        message = "Achievement valid hona chahiye.";
      } else if (achievementValue > targetValue) {
        invalidInput = achievementInput;
        message = `Achievement Target (${targetValue}) se jyada nahi ho sakta.`;
      }

      if (!invalidInput) return true;

      invalidInput.setCustomValidity(message);
      if (report) invalidInput.reportValidity();
      return false;
    };

    [vrpSelect, monthSelect, icsSelect, villageSelect, topicSelect, subjectSelect, targetInput, achievementInput].forEach((input) => {
      input?.addEventListener("input", () => validateSeedTargetForm(false));
      input?.addEventListener("change", () => validateSeedTargetForm(false));
    });

    formShell.querySelector("form")?.addEventListener("submit", (event) => {
      if (validateSeedTargetForm(true)) return;

      event.preventDefault();
    });
  });

  document.querySelectorAll("[data-vrp-ics-mapping]").forEach((shell) => {
    const vrpSelect = shell.querySelector("[data-vrp-ics-vrp]");
    const fcoSelect = shell.querySelector("[data-vrp-ics-fco]");
    const icsSelect = shell.querySelector("[data-vrp-ics-ics]");
    const villageSelect = shell.querySelector("[data-vrp-ics-village]");
    const farmersList = shell.querySelector("[data-vrp-ics-farmers]");
    const selectAll = shell.querySelector("[data-vrp-ics-select-all]");
    const countLabel = shell.querySelector("[data-vrp-ics-count]");
    const hiddenFcoName = shell.querySelector("[data-vrp-ics-fco-name]");
    const hiddenIcsName = shell.querySelector("[data-vrp-ics-ics-name]");
    const hiddenVillageName = shell.querySelector("[data-vrp-ics-village-name]");
    let editMapping = {};
    try {
      editMapping = JSON.parse(shell.dataset.editMapping || "{}");
    } catch (_error) {
      editMapping = {};
    }

    const escapeHtml = (value) => String(value || "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");

    const selectedText = (select) => select?.selectedOptions?.[0]?.textContent?.trim() || "";

    const updateHiddenNames = () => {
      if (hiddenFcoName) hiddenFcoName.value = fcoSelect?.value ? selectedText(fcoSelect) : "";
      if (hiddenIcsName) hiddenIcsName.value = icsSelect?.value ? selectedText(icsSelect) : "";
      if (hiddenVillageName) hiddenVillageName.value = villageSelect?.value ? selectedText(villageSelect) : "";
    };

    const fillSelect = (select, options, placeholder) => {
      if (!select) return;

      select.innerHTML = "";
      const blank = document.createElement("option");
      blank.value = "";
      blank.textContent = placeholder;
      select.appendChild(blank);

      options.forEach((optionData) => {
        const option = document.createElement("option");
        option.value = optionData.value || "";
        option.textContent = optionData.label || optionData.value || "";
        select.appendChild(option);
      });

      select.disabled = options.length === 0;
    };



    const selectedFarmerBoxes = () => Array.from(shell.querySelectorAll("[data-vrp-ics-farmer-checkbox]:checked"));

    const updateFarmerCount = () => {
      const count = selectedFarmerBoxes().length;
      if (countLabel) countLabel.textContent = `${count} farmer selected`;
      if (selectAll) {
        const allBoxes = Array.from(shell.querySelectorAll("[data-vrp-ics-farmer-checkbox]:not(:disabled)"));
        selectAll.checked = allBoxes.length > 0 && count === allBoxes.length;
        selectAll.indeterminate = count > 0 && count < allBoxes.length;
      }
    };

    const clearFarmers = (message = "Select FCO, ICS and Village to load farmers.") => {
      if (farmersList) farmersList.textContent = message;
      if (selectAll) {
        selectAll.checked = false;
        selectAll.indeterminate = false;
      }
      updateFarmerCount();
    };

    const renderFarmers = (farmers) => {
      if (!farmersList) return;

      if (!farmers.length) {
        clearFarmers("No farmers found for selected village.");
        return;
      }

      farmersList.innerHTML = farmers.map((farmer) => {
        const meta = [
          farmer.father_name ? `Father: ${farmer.father_name}` : "",
          farmer.tracenet_no ? `Tracenet: ${farmer.tracenet_no}` : "",
          farmer.mobile_no ? `Mobile: ${farmer.mobile_no}` : "",
          farmer.khasara_no ? `Khasara: ${farmer.khasara_no}` : ""
        ].filter(Boolean).join(" | ");

        return `
          <label class="vrp-ics-farmer-item${farmer.mapped_to_other ? " disabled" : ""}">
            <input type="checkbox" name="vrp_ics_mapping[afl_ids][]" value="${escapeHtml(farmer.id)}" data-vrp-ics-farmer-checkbox${farmer.mapped_to_other ? " disabled" : ""}${(editMapping.afl_ids || []).map(String).includes(String(farmer.id)) ? " checked" : ""}>
            <span>
              <strong>${escapeHtml(farmer.farmer_name || `Farmer #${farmer.id}`)}</strong>
              <small>${escapeHtml(meta)}${farmer.mapped_to_other ? " | Already mapped" : ""}</small>
            </span>
          </label>
        `;
      }).join("");

      farmersList.querySelectorAll("[data-vrp-ics-farmer-checkbox]").forEach((checkbox) => {
        checkbox.addEventListener("change", updateFarmerCount);
      });
      updateFarmerCount();
    };

    fcoSelect?.addEventListener("change", async () => {
      fillSelect(icsSelect, [], "Select ICS");
      fillSelect(villageSelect, [], "Select Village");
      clearFarmers();
      updateHiddenNames();

      if (!fcoSelect.value) return;

      try {
        const data = await fetchJson(shell.dataset.icsUrl, { fco_id: fcoSelect.value });
        fillSelect(icsSelect, data.options || [], "Select ICS");
      } catch (_error) {
        window.alert("ICS list load nahi ho payi.");
      }
    });

    icsSelect?.addEventListener("change", async () => {
      fillSelect(villageSelect, [], "Select Village");
      clearFarmers();
      updateHiddenNames();

      if (!fcoSelect?.value || !icsSelect.value) return;

      try {
        const data = await fetchJson(shell.dataset.villagesUrl, { fco_id: fcoSelect.value, ics_id: icsSelect.value });
        fillSelect(villageSelect, data.options || [], "Select Village");
      } catch (_error) {
        window.alert("Village list load nahi ho payi.");
      }
    });

    villageSelect?.addEventListener("change", async () => {
      clearFarmers(villageSelect.value ? "Loading farmers..." : "Select village to load farmers.");
      updateHiddenNames();

      if (!fcoSelect?.value || !icsSelect?.value || !villageSelect.value) return;

      try {
        const data = await fetchJson(shell.dataset.farmersUrl, {
          vrp_id: vrpSelect?.value,
          edit_id: editMapping.id,
          fco_id: fcoSelect.value,
          ics_id: icsSelect.value,
          village_id: villageSelect.value
        });
        renderFarmers(data.farmers || []);
      } catch (_error) {
        clearFarmers("Farmers load nahi ho paye.");
      }
    });

    selectAll?.addEventListener("change", () => {
      shell.querySelectorAll("[data-vrp-ics-farmer-checkbox]:not(:disabled)").forEach((checkbox) => {
        checkbox.checked = selectAll.checked;
      });
      updateFarmerCount();
    });

    const loadEditMapping = async () => {
      if (!editMapping.id || !fcoSelect?.value) return;

      try {
        const icsData = await fetchJson(shell.dataset.icsUrl, { fco_id: fcoSelect.value });
        fillSelect(icsSelect, icsData.options || [], "Select ICS");
        icsSelect.value = editMapping.ics_id || "";

        const villageData = await fetchJson(shell.dataset.villagesUrl, { fco_id: fcoSelect.value, ics_id: icsSelect.value });
        fillSelect(villageSelect, villageData.options || [], "Select Village");
        villageSelect.value = editMapping.village_id || "";
        updateHiddenNames();

        const farmersData = await fetchJson(shell.dataset.farmersUrl, {
          vrp_id: vrpSelect?.value,
          edit_id: editMapping.id,
          fco_id: fcoSelect.value,
          ics_id: icsSelect.value,
          village_id: villageSelect.value
        });
        renderFarmers(farmersData.farmers || []);
      } catch (_error) {
        clearFarmers("Saved mapping load nahi ho payi.");
      }
    };

    loadEditMapping();
  });

  document.querySelectorAll("[data-target-mapping]").forEach((shell) => {
    if (shell.dataset.targetMappingBound === "true") return;
    shell.dataset.targetMappingBound = "true";

    const vrpSelect = shell.querySelector("[data-target-vrp]");
    const fcoSelect = shell.querySelector("[data-target-fco]");
    const icsSelect = shell.querySelector("[data-target-ics]");
    const villageSelect = shell.querySelector("[data-target-village]");
    const villageHidden = shell.querySelector("[data-target-village-hidden]");
    const monthSelect = shell.querySelector("select[name='target_mapping[month_name]']");
    const targetTypeSelect = shell.querySelector("[data-target-type]");
    const mainActivitySelect = shell.querySelector("[data-target-main-activity]");
    const subActivitySelect = shell.querySelector("[data-target-sub-activity]");
    const subActivityField = shell.querySelector("[data-target-sub-activity-field]");
    const standardQuantityFields = Array.from(shell.querySelectorAll("[data-target-standard-quantity-fields]"));
    const farmerOnlyFields = Array.from(shell.querySelectorAll("[data-target-farmer-only-field]"));
    const trainingFieldsPanel = shell.querySelector("[data-target-training-fields]");
    const trainingTargetInputs = () => Array.from(shell.querySelectorAll("[data-training-target-input]"));
    const targetInput = shell.querySelector("[data-target-quantity-input]");
    const newFarmerTargetInput = shell.querySelector("[data-new-farmer-target-input]");
    const registeredCountInput = shell.querySelector("[data-target-registered-count]");
    const farmerPanel = shell.querySelector("[data-target-farmer-panel]");
    const farmerList = shell.querySelector("[data-target-farmer-list]");
    const farmerCountLabel = shell.querySelector("[data-target-farmer-count]");
    const farmerSelectAll = shell.querySelector("[data-target-farmer-select-all]");
    const farmerSearchInput = shell.querySelector("[data-target-farmer-search]");
    const farmerSearchEmpty = shell.querySelector("[data-target-farmer-search-empty]");
    const weeklySummary = shell.querySelector("[data-target-weekly-summary]");
    const weeklyRows = shell.querySelector("[data-target-weekly-rows]");
    const weeklyHeaderRow = shell.querySelector("[data-target-weekly-header-row]");
    const weeklyViewHeader = shell.querySelector("[data-target-weekly-view-header]");
    const weeklySelectedTotal = shell.querySelector("[data-target-weekly-selected-total]");
    const farmerDialog = shell.querySelector("[data-target-farmer-dialog]");
    const farmerDialogTitle = shell.querySelector("[data-target-farmer-dialog-title]");
    const farmerDialogTotal = shell.querySelector("[data-target-farmer-dialog-total]");
    const farmerDialogList = shell.querySelector("[data-target-dialog-farmer-list]");
    const farmerDialogSearch = shell.querySelector("[data-target-dialog-farmer-search]");
    const farmerDialogEmpty = shell.querySelector("[data-target-dialog-farmer-empty]");
    const farmerDialogSelectAll = shell.querySelector("[data-target-dialog-select-all]");
    const farmerDialogClear = shell.querySelector("[data-target-dialog-clear]");
    const farmerDialogSave = shell.querySelector("[data-target-dialog-save]");
    const farmerDialogSaveStatus = shell.querySelector("[data-target-dialog-save-status]");
    const form = shell.querySelector("form");

    const validateOpgBreakdown = (strict = false) => {
      const inputs = trainingTargetInputs().filter((input) => !input.disabled);
      const opgInput = inputs.find((input) => input.dataset.trainingActivityName === "OPG Training");
      const breakdownInputs = inputs.filter((input) => input !== opgInput);
      const breakdown = breakdownInputs.reduce((sum, input) => sum + (Number(input.value) || 0), 0);
      const opg = Number(opgInput?.value);
      let message = opgInput?.value.trim() && (breakdown > opg || (strict && breakdown !== opg))
        ? `General Training/Meeting, Input Demo INM, Input Demo PM aur FFS ka total (${breakdown}) OPG Training (${opg}) ke equal hona chahiye; usse zyada nahi ho sakta.` : "";
      if (strict && opgInput && !opgInput.value.trim() && breakdown > 0) message = "Please enter OPG Training before allocating the four training targets.";
      const missing = inputs.filter((input) => !input.value.trim());
      if (missing.length) message = `Please fill ${missing.map((input) => input.dataset.trainingActivityName === "FFS" ? "FFS Exposure" : input.dataset.trainingActivityName).join(", ")}. Enter 0 for sub-targets with no allocation.`;
      trainingTargetInputs().forEach((input) => input.setCustomValidity(""));
      if (message) opgInput.setCustomValidity(message);
      const warning = shell.querySelector("[data-opg-validation-message]");
      if (warning) {
        warning.textContent = message || (opgInput?.value.trim() ? `${breakdown} / ${opg} OPG Training allocated` : "");
        warning.hidden = !warning.textContent;
      }
      return message;
    };
    trainingTargetInputs().forEach((input) => input.addEventListener("input", () => validateOpgBreakdown(true)));
    form?.addEventListener("submit", (event) => {
      const message = validateOpgBreakdown(true);
      if (!message) return;
      event.preventDefault();
      form.reportValidity();
    });

    const savedEditFarmerIds = () => {
      const ids = Array.from(shell.querySelectorAll("[data-edit-saved-target-farmer-id]"))
        .map((input) => String(input.value || ""))
        .filter(Boolean);
      if (ids.length) return [...new Set(ids)];

      return Array(editTarget.afl_ids || []).map((id) => String(id)).filter(Boolean);
    };
    let editTarget = {};
    let targetSubActivityRows = [];
    let mainActivityTypeRows = [];
    let targetLoadRequestId = 0;
    let targetLoadAbortController;
    let activeFarmerDialogRowKey = "";
    const weeklyPlanValues = {};
    const weeklyPlanFarmerIds = {};
    const weeklyPlanFarmerIdsDirty = new Set();
    try {
      editTarget = JSON.parse(shell.dataset.editTarget || "{}");
    } catch (_error) {
      editTarget = {};
    }
    try {
      targetSubActivityRows = JSON.parse(shell.dataset.targetSubActivityMap || "[]");
    } catch (_error) {
      targetSubActivityRows = [];
    }
    try {
      mainActivityTypeRows = JSON.parse(shell.dataset.mainActivityTypeMap || "[]");
    } catch (_error) {
      mainActivityTypeRows = [];
    }
    if (mainActivitySelect && !mainActivitySelect.dataset.originalOptions) {
      mainActivitySelect.dataset.originalOptions = JSON.stringify(Array.from(mainActivitySelect.options || []).map((option) => ({
        value: option.value,
        label: option.textContent || ""
      })));
    }
    let originalMainActivityOptions = [];
    try {
      originalMainActivityOptions = JSON.parse(mainActivitySelect?.dataset.originalOptions || "[]");
    } catch (_error) {
      originalMainActivityOptions = [];
    }

    const escapeHtml = (value) => String(value || "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");

    const selectedTargetBoxes = () => Array.from(shell.querySelectorAll("[data-target-farmer-checkbox]:checked"));
    const targetBoxes = () => Array.from(shell.querySelectorAll("[data-target-farmer-checkbox]"));
    const availableTargetBoxes = () => targetBoxes().filter((checkbox) => !checkbox.disabled);
    const visibleAvailableTargetBoxes = () => availableTargetBoxes().filter((checkbox) => !checkbox.closest(".vrp-ics-farmer-item")?.hidden);
    const targetFarmerSearchTerm = () => (farmerSearchInput?.value || "").trim().toLowerCase();
    const villageTargetMode = () => (targetTypeSelect?.value || "").trim().toLowerCase() === "village";
    const newFarmerTargetMode = () => (newFarmerTargetInput?.value || "").trim() !== "";
    const clearNewFarmerTargetForSelection = () => {
      if (!newFarmerTargetInput || !newFarmerTargetMode()) return;

      newFarmerTargetInput.value = "";
      syncNewFarmerTargetMode();
    };
    const syncNewFarmerTargetMode = () => {
      if (!targetInput) return;

      const manualMode = newFarmerTargetMode();
      targetInput.disabled = manualMode && !villageTargetMode();
      targetInput.required = !manualMode || villageTargetMode();
      targetInput.setCustomValidity("");
    };
    const locationValueParts = (value) => `${value || ""}`.split("||");
    const targetOptionMatches = (optionValueText, selectedValueText) => {
      const optionParts = locationValueParts(optionValueText);
      const selectedParts = locationValueParts(selectedValueText);
      if (selectedParts[1]) return normalizeOption(optionValueText) === normalizeOption(selectedValueText);

      return normalizeOption(optionParts[0]) === normalizeOption(selectedParts[0]);
    };
    const targetSelectedValuesFromDataset = (select) => {
      if (!select) return [];

      if (select.dataset.selectedValues) {
        try {
          const values = JSON.parse(select.dataset.selectedValues);
          if (Array.isArray(values)) return values.map((value) => String(value)).filter(Boolean);
        } catch (_error) {
          return select.dataset.selectedValues.split(",").map((value) => value.trim()).filter(Boolean);
        }
      }

      return select.dataset.selectedValue ? [select.dataset.selectedValue] : [];
    };
    const targetSelectedValues = (select) => {
      if (!select) return [];

      const selected = Array.from(select.selectedOptions || []).map((option) => option.value).filter(Boolean);
      if (select.dataset.selectionDirty === "true") return selected;

      return selected.length ? selected : targetSelectedValuesFromDataset(select);
    };
    const syncTargetVillageHidden = () => {
      if (!villageHidden || !villageSelect) return;

      villageHidden.value = JSON.stringify(targetSelectedValues(villageSelect));
    };

    const fillTargetSelect = (select, options, placeholder) => {
      if (!select) return;

      const selectedValues = targetSelectedValues(select);
      select.innerHTML = "";

      const blank = document.createElement("option");
      blank.value = "";
      blank.textContent = options.length ? placeholder : `No ${placeholder.replace(/^Select\s+/i, "")} saved yet`;
      select.appendChild(blank);

      options.forEach((optionData) => {
        const option = document.createElement("option");
        option.value = optionValue(optionData);
        option.textContent = optionLabel(optionData);
        option.selected = selectedValues.some((selected) => targetOptionMatches(option.value, selected));
        select.appendChild(option);
      });

      delete select.dataset.selectedValue;
      delete select.dataset.selectedValues;
      select.disabled = options.length === 0;
      select.dispatchEvent(new Event("chip:refresh"));
    };
    const clearTargetVillageSelection = () => {
      if (!villageSelect) return;

      Array.from(villageSelect.options || []).forEach((option) => {
        option.selected = false;
      });
      villageSelect.dataset.selectionDirty = "true";
      villageSelect.dispatchEvent(new Event("chip:refresh"));
    };

    const selectedMainActivityNames = () => targetSelectedValues(mainActivitySelect);
    const selectedSubActivityNames = () => targetSelectedValues(subActivitySelect);
    const mainActivityTypeFor = (mainActivityName) => {
      const match = mainActivityTypeRows.find((row) => normalizeOption(row.main_activity) === normalizeOption(mainActivityName));
      return normalizeOption(match?.main_activity_type || "Training");
    };
    const trainingActivityTypeSelected = () => {
      const selected = selectedMainActivityNames();
      if (!selected.length) return false;

      return selected.some((name) => mainActivityTypeFor(name) === normalizeOption("Training"));
    };
    const filledTrainingTargets = () => trainingTargetInputs().filter((input) => String(input.value || "").trim() !== "");
    const refreshMainActivityOptionsForTargetType = (resetSelection = false) => {
      if (!mainActivitySelect || !originalMainActivityOptions.length) return;

      const selectedValues = resetSelection ? [] : targetSelectedValues(mainActivitySelect);
      const filteredOptions = originalMainActivityOptions.filter((option) => {
        if (!option.value) return true;
        return !villageTargetMode() || mainActivityTypeFor(option.value) !== normalizeOption("Training");
      });

      mainActivitySelect.innerHTML = "";
      filteredOptions.forEach((optionData) => {
        const option = document.createElement("option");
        option.value = optionData.value;
        option.textContent = optionData.label;
        option.selected = selectedValues.some((selected) => targetOptionMatches(option.value, selected));
        mainActivitySelect.appendChild(option);
      });
      mainActivitySelect.disabled = filteredOptions.filter((option) => option.value).length === 0;
      mainActivitySelect.dataset.selectionDirty = "true";
      delete mainActivitySelect.dataset.selectedValue;
      delete mainActivitySelect.dataset.selectedValues;
      mainActivitySelect.dispatchEvent(new Event("chip:refresh"));
    };

    const targetSubActivityOptionsForMain = () => {
      const selectedMainActivities = selectedMainActivityNames().map((value) => normalizeOption(value));
      if (!selectedMainActivities.length) return [];

      return uniqueOptions(
        targetSubActivityRows
          .filter((row) => selectedMainActivities.includes(normalizeOption(row.main_activity)))
          .map((row) => makeOption(row.sub_activity, row.sub_activity))
      );
    };

    const syncTargetActivityMode = () => {
      const trainingMode = trainingActivityTypeSelected();
      const villageMode = villageTargetMode();

      // Sub Activity always stays visible and enabled (loads from selected Main Activity).
      if (subActivityField) {
        subActivityField.hidden = false;
        subActivityField.removeAttribute("hidden");
      }
      if (subActivitySelect) {
        subActivitySelect.required = true;
        // Keep enabled unless options are empty — refreshTargetSubActivities manages that.
      }

      // Keep the source farmer list hidden in the form. Its checkboxes feed the
      // Activity Wise Plan farmer dialog and are still submitted with the form.
      if (farmerPanel) {
        farmerPanel.hidden = true;
      }

      standardQuantityFields.forEach((field) => {
        field.hidden = false;
        field.removeAttribute("hidden");
        field.querySelectorAll("input").forEach((input) => {
          // Do not disable these fields for Training mode.
          // if (trainingMode) { input.disabled = true; ... }
          if (input.matches("[data-target-quantity-input]")) {
            // target stays readonly (auto from farmer selection) — only toggle via New Farmer Target mode
            input.required = true;
          }
        });
      });
      farmerOnlyFields.forEach((field) => {
        field.hidden = villageMode;
        if (villageMode) field.setAttribute("hidden", "hidden");
        else field.removeAttribute("hidden");
        field.querySelectorAll("input").forEach((input) => {
          input.disabled = villageMode;
          if (villageMode) input.setCustomValidity("");
        });
      });

      if (trainingFieldsPanel) trainingFieldsPanel.hidden = !trainingMode || villageMode;

      trainingTargetInputs().forEach((input) => {
        input.disabled = !trainingMode || villageMode;
        input.required = !input.disabled;
        if (input.disabled) input.setCustomValidity("");
        if ((!trainingMode || villageMode) && !editTarget.id) input.value = "";
      });

      validateOpgBreakdown(true);
      syncNewFarmerTargetMode();
    };

    const refreshTargetSubActivities = (resetSelection = false) => {
      if (!subActivitySelect) return;

      if (resetSelection) {
        subActivitySelect.dataset.selectedValues = "[]";
        Array.from(subActivitySelect.options || []).forEach((option) => {
          option.selected = false;
        });
        subActivitySelect.dataset.selectionDirty = "true";
      }

      if (!selectedMainActivityNames().length) {
        subActivitySelect.innerHTML = '<option value="">Select Main Activity first</option>';
        subActivitySelect.disabled = true;
        subActivitySelect.dispatchEvent(new Event("chip:refresh"));
        return;
      }

      fillTargetSelect(subActivitySelect, targetSubActivityOptionsForMain(), "Select Sub Activity");
    };

    const selectedFarmerMonthlyCount = () => {
      const manualTarget = Number(newFarmerTargetInput?.value || 0);
      if (Number.isInteger(manualTarget) && manualTarget > 0) return manualTarget;

      return selectedTargetBoxes().length;
    };

    const weeklyCountsFor = (monthlyCount) => {
      const count = Number(monthlyCount || 0);
      if (!Number.isInteger(count) || count <= 0) return [0, 0, 0, 0];

      const base = Math.floor(count / 4);
      const remainder = count % 4;
      return [0, 1, 2, 3].map((index) => base + (index < remainder ? 1 : 0));
    };

    const trainingMonthlyTargetFor = (row) => {
      const activityText = `${row.subActivity || ""} ${row.label || ""}`.toLowerCase();
      const matchingInput = trainingTargetInputs().find((input) => {
        const trainingName = String(input.dataset.trainingActivityName || "").trim().toLowerCase();
        return trainingName && activityText.includes(trainingName);
      });
      return matchingInput?.value || "";
    };

    const activityLabelHtml = (row) => {
      const mainActivity = row.mainActivityLabel || row.mainActivity || "";
      const subActivities = Array.isArray(row.subActivityLabels) ? row.subActivityLabels : [];
      const subLabel = subActivities.length
        ? `<div class="target-weekly-subactivities">${subActivities.map((subActivity) => `<div class="target-weekly-subactivity"><span>${escapeHtml(subActivity)}</span></div>`).join("")}</div>`
        : "";
      return `<div class="target-weekly-activity"><strong>${escapeHtml(mainActivity)}</strong>${subLabel}</div>`;
    };

    const targetActivitySummaryRows = () => {
      const mainActivities = selectedMainActivityNames();
      if (!mainActivities.length) return [];
      const subActivities = selectedSubActivityNames();
      return [{
        mainActivity: "__common__",
        mainActivityLabel: mainActivities.join(", "),
        subActivityLabels: subActivities,
        subActivity: "",
        label: mainActivities.join(", ")
      }];
    };

    const weeklyRowKey = (row) => `${row.mainActivity || ""}`;
    const farmerIdsForRow = (rowKey) => {
      const mainActivity = String(rowKey || "");
      const savedFarmerIds = savedEditFarmerIds();
      const editRowMatches = editTarget.id &&
        normalizeOption(mainActivity) === normalizeOption(editTarget.main_activity_names?.[0]);

      if (editRowMatches && savedFarmerIds.length && !weeklyPlanFarmerIdsDirty.has(rowKey)) {
        weeklyPlanFarmerIds[rowKey] = new Set(savedFarmerIds);
      } else {
        weeklyPlanFarmerIds[rowKey] ||= new Set();
      }
      return weeklyPlanFarmerIds[rowKey];
    };
    const restoreEditFarmerSelections = (rows) => {
      if (!editTarget.id || editTarget.farmerSelectionsRestored) return;

      const savedFarmerIds = savedEditFarmerIds();
      if (!savedFarmerIds.length || !rows.length) return;

      const matchingRow = rows.find((row) => (
        normalizeOption(row.mainActivity) === normalizeOption(editTarget.main_activity_names?.[0])
      ));
      if (!matchingRow) return;

      weeklyPlanFarmerIds[weeklyRowKey(matchingRow)] = new Set(savedFarmerIds);
      editTarget.farmerSelectionsRestored = true;
    };
    const selectedFarmerIdsForActiveRow = () => farmerIdsForRow(activeFarmerDialogRowKey);
    const totalActivityFarmerSelections = () => Object.values(weeklyPlanFarmerIds).reduce((total, ids) => total + ids.size, 0);
    const weeklyPlanValue = (row, field, fallback = "") => {
      const savedValue = weeklyPlanValues[weeklyRowKey(row)]?.[field];
      return savedValue === undefined ? fallback : savedValue;
    };
    const weeklyMonthlyLimit = (rowKey) => {
      const savedValue = weeklyPlanValues[rowKey]?.monthly;
      if (savedValue !== undefined) return Number(savedValue || 0);

      const monthlyInput = weeklyRows?.querySelector(`[data-weekly-row-key="${CSS.escape(rowKey)}"][data-weekly-field="monthly"]`);
      return Number(monthlyInput?.value || 0);
    };
    const activeFarmerLimit = () => weeklyMonthlyLimit(activeFarmerDialogRowKey);
    const farmerLimitMessage = (limit) => `Monthly target ${limit} hai. Aap maximum ${limit} farmers hi select kar sakte hain.`;
    const weeklyPlanInput = (row, index, field, fallback = "") => `
      <input
        type="number"
        min="0"
        step="1"
        class="target-weekly-input"
        name="target_mapping[weekly_plan][${index}][${field}]"
        value="${escapeHtml(weeklyPlanValue(row, field, fallback))}"
        data-target-weekly-input
        data-weekly-row-key="${escapeHtml(weeklyRowKey(row))}"
        data-weekly-field="${escapeHtml(field)}">
    `;

    const renderTargetWeeklySummary = () => {
      if (!weeklySummary || !weeklyRows) return;

      const rows = targetActivitySummaryRows();
      restoreEditFarmerSelections(rows);
      const monthlyCount = selectedFarmerMonthlyCount();
      const selectedLabel = `${totalActivityFarmerSelections()} total farmer selections`;
      if (weeklySelectedTotal) weeklySelectedTotal.textContent = villageTargetMode() ? "Village target" : selectedLabel;
      if (weeklyViewHeader) weeklyViewHeader.hidden = villageTargetMode();
      const totalHeader = weeklyHeaderRow?.querySelector("th:nth-last-child(2)");
      if (totalHeader) totalHeader.hidden = villageTargetMode();

      weeklySummary.hidden = rows.length === 0;
      weeklySummary.classList.toggle("target-weekly-village-mode", villageTargetMode());
      if (!rows.length) {
        weeklyRows.innerHTML = `<tr><td colspan="${villageTargetMode() ? 6 : 8}">Select Main Activity to view weekly plan.</td></tr>`;
        return;
      }

      weeklyRows.innerHTML = rows.map((row, index) => {
        const rowKey = weeklyRowKey(row);
        const selectedIds = farmerIdsForRow(rowKey);
        const rowMonthlyCount = trainingMonthlyTargetFor(row) || monthlyCount;
        const rowWeeklyCounts = weeklyCountsFor(rowMonthlyCount);
        const farmerInputs = villageTargetMode() ? "" : Array.from(selectedIds).map((id) => `<input type="hidden" name="target_mapping[weekly_plan][${index}][afl_ids][]" value="${escapeHtml(id)}">`).join("");
        const viewCell = villageTargetMode() ? "" : `<td><div class="target-weekly-cell-center"><button type="button" class="table-action" data-target-weekly-view="${index}" data-weekly-row-key="${escapeHtml(weeklyRowKey(row))}" data-activity-label="${escapeHtml(row.label)}">View</button></div></td>`;
        const totalCell = villageTargetMode() ? "" : `<td><div class="target-weekly-cell-center"><strong data-target-weekly-farmer-total>${selectedIds.size}</strong>${farmerInputs}</div></td>`;
        return `
        <tr>
          <td>
            ${activityLabelHtml(row)}
            <input type="hidden" name="target_mapping[weekly_plan][${index}][main_activity]" value="${escapeHtml(row.mainActivity)}">
            <input type="hidden" name="target_mapping[weekly_plan][${index}][sub_activity]" value="${escapeHtml(row.subActivity)}">
          </td>
          <td><div class="target-weekly-cell-center">${weeklyPlanInput(row, index, "monthly", rowMonthlyCount)}</div></td>
          <td><div class="target-weekly-cell-center">${weeklyPlanInput(row, index, "week_1", rowWeeklyCounts[0])}</div></td>
          <td><div class="target-weekly-cell-center">${weeklyPlanInput(row, index, "week_2", rowWeeklyCounts[1])}</div></td>
          <td><div class="target-weekly-cell-center">${weeklyPlanInput(row, index, "week_3", rowWeeklyCounts[2])}</div></td>
          <td><div class="target-weekly-cell-center">${weeklyPlanInput(row, index, "week_4", rowWeeklyCounts[3])}</div></td>
          ${totalCell}
          ${viewCell}
        </tr>
      `;
      }).join("");
    };

    const dialogFarmerSearchTerm = () => (farmerDialogSearch?.value || "").trim().toLowerCase();

    const syncDialogFarmerTotals = () => {
      if (villageTargetMode()) {
        if (weeklySelectedTotal) weeklySelectedTotal.textContent = "Village target";
        return;
      }
      const limit = activeFarmerLimit();
      const selectedCount = activeFarmerDialogRowKey ? selectedFarmerIdsForActiveRow().size : 0;
      const selectedLabel = activeFarmerDialogRowKey && Number.isInteger(limit) && limit > 0
        ? `${selectedCount} / ${limit} farmer selected`
        : `${selectedCount} farmer selected`;
      if (farmerDialogTotal) farmerDialogTotal.textContent = selectedLabel;
      if (weeklySelectedTotal) weeklySelectedTotal.textContent = `${totalActivityFarmerSelections()} total farmer selections`;
    };

    const renderDialogFarmers = () => {
      if (!farmerDialogList) return;

      const boxes = targetBoxes();
      const selectedIds = selectedFarmerIdsForActiveRow();
      if (!boxes.length) {
        farmerDialogList.textContent = farmerList?.textContent || "Select FCO Name, ICS and Village to load farmers.";
        if (farmerDialogEmpty) farmerDialogEmpty.hidden = true;
        syncDialogFarmerTotals();
        return;
      }

      const term = dialogFarmerSearchTerm();
      let visibleCount = 0;
      farmerDialogList.innerHTML = boxes.map((box) => {
        const item = box.closest(".vrp-ics-farmer-item");
        const text = item?.innerText || "";
        const alreadyMapped = item?.classList.contains("already-mapped") || item?.classList.contains("already-included");
        const visible = !term || text.toLowerCase().includes(term);
        if (visible) visibleCount += 1;

        return `
          <label class="vrp-ics-farmer-item${alreadyMapped ? " already-included" : ""}"${visible ? "" : " hidden"}>
            <input type="checkbox" value="${escapeHtml(box.value)}" data-target-dialog-farmer-checkbox${selectedIds.has(String(box.value)) ? " checked" : ""}>
            <span>${item?.querySelector("span")?.innerHTML || escapeHtml(text)}</span>
          </label>
        `;
      }).join("");

      farmerDialogList.querySelectorAll("[data-target-dialog-farmer-checkbox]").forEach((dialogBox) => {
        dialogBox.addEventListener("change", () => {
          const sourceBox = targetBoxes().find((box) => String(box.value) === String(dialogBox.value));
          if (!sourceBox) return;

          const limit = activeFarmerLimit();
          const selectedIds = selectedFarmerIdsForActiveRow();
          if (dialogBox.checked && Number.isInteger(limit) && limit > 0 && selectedIds.size >= limit) {
            dialogBox.checked = false;
            window.alert(farmerLimitMessage(limit));
            return;
          }

          if (dialogBox.checked) selectedIds.add(String(dialogBox.value));
          else selectedIds.delete(String(dialogBox.value));
          if (dialogBox.checked) clearNewFarmerTargetForSelection();
          weeklyPlanFarmerIdsDirty.add(activeFarmerDialogRowKey);
          syncDialogFarmerTotals();
          renderTargetWeeklySummary();
        });
      });

      if (farmerDialogEmpty) farmerDialogEmpty.hidden = visibleCount > 0;
      syncDialogFarmerTotals();
    };

    const openTargetFarmerDialog = (activityLabel, rowKey) => {
      if (!farmerDialog) return;

      activeFarmerDialogRowKey = rowKey || "";
      if (farmerDialogTitle) farmerDialogTitle.textContent = activityLabel || "Farmer List";
      if (farmerDialogSearch) farmerDialogSearch.value = "";
      if (farmerDialogSave) farmerDialogSave.textContent = "Save Farmers";
      if (farmerDialogSaveStatus) farmerDialogSaveStatus.textContent = "Select farmers, then save the selection.";
      renderDialogFarmers();

      if (typeof farmerDialog.showModal === "function") farmerDialog.showModal();
      else farmerDialog.setAttribute("open", "open");
    };

    const updateTargetFarmerCount = () => {
      const selectedCount = selectedTargetBoxes().length;
      const totalCount = targetBoxes().length;
      const availableBoxes = visibleAvailableTargetBoxes();
      const availableCount = availableBoxes.length;
      const visibleSelectedCount = availableBoxes.filter((checkbox) => checkbox.checked).length;
      if (farmerCountLabel) farmerCountLabel.textContent = `${selectedCount} farmer selected`;
      if (registeredCountInput) registeredCountInput.value = String(totalCount);
      if (targetInput) targetInput.value = villageTargetMode() ? String(totalCount) : String(selectedCount);
      if (targetInput) targetInput.max = String(availableTargetBoxes().length || selectedCount || totalCount || 1);
      syncNewFarmerTargetMode();
      if (farmerSelectAll) {
        farmerSelectAll.checked = availableCount > 0 && visibleSelectedCount === availableCount;
        farmerSelectAll.indeterminate = visibleSelectedCount > 0 && visibleSelectedCount < availableCount;
        farmerSelectAll.disabled = availableCount === 0;
      }
      syncDialogFarmerTotals();
      renderTargetWeeklySummary();
    };

    const applyTargetFarmerSearch = () => {
      if (!farmerList) return;

      const term = targetFarmerSearchTerm();
      const items = Array.from(farmerList.querySelectorAll(".vrp-ics-farmer-item"));
      let visibleCount = 0;

      items.forEach((item) => {
        const visible = !term || item.innerText.toLowerCase().includes(term);
        item.hidden = !visible;
        if (visible) visibleCount += 1;
      });

      if (farmerSearchEmpty) farmerSearchEmpty.hidden = visibleCount > 0 || !items.length;
      updateTargetFarmerCount();
    };

    const clearTargetFarmers = (message = "Select FCO Name, ICS and Village to load farmers.") => {
      if (farmerList) farmerList.textContent = message;
      if (farmerSearchEmpty) farmerSearchEmpty.hidden = true;
      updateTargetFarmerCount();
    };

    const renderTargetFarmers = (farmers) => {
      if (!farmerPanel || !farmerList) return;

      if (!farmers.length) {
        farmerList.textContent = "No farmers found for selected village.";
        if (farmerSearchEmpty) farmerSearchEmpty.hidden = true;
        updateTargetFarmerCount();
        return;
      }

      farmerList.innerHTML = farmers.map((farmer) => {
        const meta = [
          farmer.father_name ? `Father: ${farmer.father_name}` : "",
          farmer.tracenet_no ? `Tracenet: ${farmer.tracenet_no}` : "",
          farmer.mobile_no ? `Mobile: ${farmer.mobile_no}` : "",
          farmer.khasara_no ? `Khasara: ${farmer.khasara_no}` : ""
        ].filter(Boolean).join(" | ");
        const alreadyMapped = farmer.already_mapped;
        const checked = farmer.selected ? " checked" : "";

        return `
          <label class="vrp-ics-farmer-item${alreadyMapped ? " already-included" : ""}">
            <input type="checkbox" name="target_mapping[afl_ids][]" value="${escapeHtml(farmer.id)}" data-target-farmer-checkbox${checked}>
            <span>
              <strong>${escapeHtml(farmer.farmer_name || `Farmer #${farmer.id}`)}</strong>
              <small>${escapeHtml(meta)}</small>
            </span>
          </label>
        `;
      }).join("");
      applyTargetFarmerSearch();

      farmerList.querySelectorAll("[data-target-farmer-checkbox]").forEach((checkbox) => {
        checkbox.addEventListener("change", () => {
          if (checkbox.checked) clearNewFarmerTargetForSelection();
          updateTargetFarmerCount();
          if (farmerDialog?.open) renderDialogFarmers();
        });
      });
      updateTargetFarmerCount();
    };

    const loadTargetData = async () => {
      const requestId = ++targetLoadRequestId;
      targetLoadAbortController?.abort();
      targetLoadAbortController = new AbortController();
      const signal = targetLoadAbortController.signal;
      const status = shell.querySelector("[data-target-load-status]");
      if (status) { status.hidden = false; status.textContent = "Loading mapping options..."; }
      const url = new URL(shell.dataset.mappingsUrl, window.location.origin);
      if (vrpSelect?.value) url.searchParams.set("vrp_id", vrpSelect.value);
      const fcoValue = fcoSelect?.value || fcoSelect?.dataset.selectedValue;
      const icsValue = icsSelect?.value || icsSelect?.dataset.selectedValue;
      const villageValues = targetSelectedValues(villageSelect);
      if (fcoValue) url.searchParams.set("fco_id", fcoValue);
      if (icsValue) url.searchParams.set("ics_id", icsValue);
      if (villageValues.length) url.searchParams.set("village_ids", JSON.stringify(villageValues));
      if (monthSelect?.value) url.searchParams.set("month_name", monthSelect.value);
      const mainActivityValues = targetSelectedValues(mainActivitySelect);
      const subActivityValues = targetSelectedValues(subActivitySelect);
      if (mainActivityValues.length) url.searchParams.set("main_activity_name", JSON.stringify(mainActivityValues));
      if (subActivityValues.length) url.searchParams.set("activity_name", JSON.stringify(subActivityValues));
      if (targetTypeSelect?.value) url.searchParams.set("target_type", targetTypeSelect.value);
      if (editTarget.id) url.searchParams.set("edit_id", editTarget.id);

      try {
        const response = await fetch(url, { headers: { Accept: "application/json" }, signal });
        if (!response.ok) throw new Error("Request failed");
        const data = await response.json();
        if (requestId !== targetLoadRequestId) return;

        if (status) status.hidden = true;
        fillTargetSelect(fcoSelect, data.fco_options || [], "Select FCO Name");
        fillTargetSelect(icsSelect, data.ics_options || [], "Select ICS");
        fillTargetSelect(villageSelect, data.village_options || [], "Select Village");
        syncTargetVillageHidden();

        if (targetSelectedValues(villageSelect).length) {
          renderTargetFarmers(data.farmers || []);
        } else {
          clearTargetFarmers();
        }
      } catch (_error) {
        if (requestId !== targetLoadRequestId) return;

        if (status) {
          status.textContent = "Mapping options could not load. ";
          const retry = document.createElement("button");
          retry.type = "button";
          retry.className = "list-btn";
          retry.textContent = "Retry";
          retry.addEventListener("click", loadTargetData);
          status.append(retry);
        }
        console.error("Target farmers load failed", _error);
        clearTargetFarmers("Farmers load nahi ho paye.");
      }
    };

    farmerSelectAll?.addEventListener("change", () => {
      visibleAvailableTargetBoxes().forEach((checkbox) => {
        checkbox.checked = farmerSelectAll.checked;
      });
      if (farmerSelectAll.checked) clearNewFarmerTargetForSelection();
      updateTargetFarmerCount();
    });

    farmerSearchInput?.addEventListener("input", applyTargetFarmerSearch);
    weeklyRows?.addEventListener("click", (event) => {
      const button = event.target.closest("[data-target-weekly-view]");
      if (!button) return;

      openTargetFarmerDialog(button.dataset.activityLabel || "Farmer List", button.dataset.weeklyRowKey);
    });
    weeklyRows?.addEventListener("input", (event) => {
      const input = event.target.closest("[data-target-weekly-input]");
      if (!input) return;

      weeklyPlanValues[input.dataset.weeklyRowKey] ||= {};
      weeklyPlanValues[input.dataset.weeklyRowKey][input.dataset.weeklyField] = input.value;

      if (input.dataset.weeklyField === "monthly") {
        const limit = Number(input.value || 0);
        const selectedIds = farmerIdsForRow(input.dataset.weeklyRowKey);
        if (Number.isInteger(limit) && limit >= 0 && selectedIds.size > limit) {
          Array.from(selectedIds).slice(limit).forEach((id) => selectedIds.delete(id));
          weeklyPlanFarmerIdsDirty.add(input.dataset.weeklyRowKey);
          renderTargetWeeklySummary();
          window.alert(farmerLimitMessage(limit));
        }
      }
    });
    farmerDialog?.querySelector("[data-target-farmer-dialog-close]")?.addEventListener("click", () => {
      if (typeof farmerDialog.close === "function") farmerDialog.close();
      else farmerDialog.removeAttribute("open");
    });
    farmerDialogSearch?.addEventListener("input", renderDialogFarmers);
    farmerDialogSearch?.addEventListener("keydown", (event) => {
      if (event.key === "Enter") event.preventDefault();
    });
    farmerDialogSelectAll?.addEventListener("click", () => {
      const limit = activeFarmerLimit();
      const available = availableTargetBoxes();
      const selectedIds = selectedFarmerIdsForActiveRow();
      selectedIds.clear();
      available.forEach((checkbox, index) => {
        if (!Number.isInteger(limit) || limit < 0 || index < limit) selectedIds.add(String(checkbox.value));
      });
      if (selectedIds.size) clearNewFarmerTargetForSelection();
      weeklyPlanFarmerIdsDirty.add(activeFarmerDialogRowKey);
      renderTargetWeeklySummary();
      renderDialogFarmers();
      if (Number.isInteger(limit) && limit >= 0 && available.length > limit) {
        window.alert(farmerLimitMessage(limit));
      }
    });
    farmerDialogClear?.addEventListener("click", () => {
      selectedFarmerIdsForActiveRow().clear();
      weeklyPlanFarmerIdsDirty.add(activeFarmerDialogRowKey);
      renderTargetWeeklySummary();
      renderDialogFarmers();
    });
    farmerDialogSave?.addEventListener("click", () => {
      const selectedCount = selectedFarmerIdsForActiveRow().size;
      renderTargetWeeklySummary();
      if (farmerDialogSave) farmerDialogSave.textContent = `Saved (${selectedCount})`;
      if (farmerDialogSaveStatus) {
        farmerDialogSaveStatus.textContent = "Farmer selection saved in the form. Submit Target to save the target.";
      }
      window.setTimeout(() => {
        if (typeof farmerDialog?.close === "function") farmerDialog.close();
        else farmerDialog?.removeAttribute("open");
      }, 500);
    });
    newFarmerTargetInput?.addEventListener("input", () => {
      syncNewFarmerTargetMode();
      updateTargetFarmerCount();
    });
    trainingTargetInputs().forEach((input) => {
      input.addEventListener("input", renderTargetWeeklySummary);
    });

    form?.addEventListener("submit", (event) => {
      syncTargetVillageHidden();
      syncNewFarmerTargetMode();

      const weeklyInputs = Array.from(weeklyRows?.querySelectorAll("[data-target-weekly-input]") || []);
      const weeklyRowKeys = [...new Set(weeklyInputs.map((input) => input.dataset.weeklyRowKey))];
      for (const rowKey of weeklyRowKeys) {
        const rowInputs = weeklyInputs.filter((input) => input.dataset.weeklyRowKey === rowKey);
        const valueFor = (field) => Number(rowInputs.find((input) => input.dataset.weeklyField === field)?.value || 0);
        const monthly = valueFor("monthly");
        const weeklyTotal = ["week_1", "week_2", "week_3", "week_4"].reduce((total, field) => total + valueFor(field), 0);

        if (!Number.isInteger(monthly) || monthly <= 0 || weeklyTotal !== monthly) {
          event.preventDefault();
          window.alert(`Week 1, Week 2, Week 3 aur Week 4 ka total Monthly target (${monthly}) ke equal hona chahiye.`);
          return;
        }

        if (!villageTargetMode() && !newFarmerTargetMode() && farmerIdsForRow(rowKey).size !== monthly) {
          event.preventDefault();
          window.alert(`Monthly target ${monthly} hai, isliye exactly ${monthly} farmers select karein.`);
          return;
        }
      }

      if (trainingActivityTypeSelected() && !villageTargetMode()) {
        const filled = filledTrainingTargets();
        const invalid = filled.find((input) => {
          const value = Number(input.value || 0);
          return !Number.isInteger(value) || value < 0;
        });
        if (invalid) {
          event.preventDefault();
          window.alert("Training target values must be non-negative whole numbers.");
          return;
        }
      }

      if (newFarmerTargetMode()) {
        const manualTargetCount = Number(newFarmerTargetInput.value || 0);
        if (!Number.isInteger(manualTargetCount) || manualTargetCount <= 0) {
          event.preventDefault();
          window.alert("New Farmer Target must be a whole number greater than 0.");
        }
        return;
      }

      if (weeklyRowKeys.length) return;

      const selectedCount = selectedTargetBoxes().length;
      const targetCount = Number(targetInput.value || 0);
      if (!selectedCount) {
        event.preventDefault();
        window.alert("Please select at least one farmer.");
        return;
      }
      if (targetCount !== selectedCount) {
        event.preventDefault();
        window.alert(`Target must match selected farmers count (${selectedCount}).`);
      }
    });

    fcoSelect?.addEventListener("change", () => {
      fcoSelect.dataset.selectedValue = "";
      if (icsSelect) icsSelect.dataset.selectedValue = "";
      if (villageSelect) villageSelect.dataset.selectedValue = "";
      if (villageSelect) villageSelect.dataset.selectedValues = "[]";
      if (icsSelect) icsSelect.value = "";
      clearTargetVillageSelection();
      syncTargetVillageHidden();
      clearTargetFarmers();
      loadTargetData();
    });
    icsSelect?.addEventListener("change", () => {
      icsSelect.dataset.selectedValue = "";
      if (villageSelect) villageSelect.dataset.selectedValue = "";
      if (villageSelect) villageSelect.dataset.selectedValues = "[]";
      clearTargetVillageSelection();
      syncTargetVillageHidden();
      clearTargetFarmers();
      loadTargetData();
    });
    villageSelect?.addEventListener("change", () => {
      syncTargetVillageHidden();
      clearTargetFarmers();
      loadTargetData();
    });
    vrpSelect?.addEventListener("change", loadTargetData);
    monthSelect?.addEventListener("change", loadTargetData);
    mainActivitySelect?.addEventListener("change", () => {
      refreshTargetSubActivities(true);
      syncTargetActivityMode();
      renderTargetWeeklySummary();
      loadTargetData();
    });
    subActivitySelect?.addEventListener("change", () => {
      renderTargetWeeklySummary();
      loadTargetData();
    });
    targetTypeSelect?.addEventListener("change", () => {
      refreshMainActivityOptionsForTargetType(true);
      refreshTargetSubActivities(true);
      syncTargetActivityMode();
      renderTargetWeeklySummary();
      loadTargetData();
    });

    refreshMainActivityOptionsForTargetType(false);
    refreshTargetSubActivities(false);
    syncTargetActivityMode();
    syncTargetVillageHidden();
    syncNewFarmerTargetMode();
    renderTargetWeeklySummary();
    loadTargetData();
  });

  document.addEventListener("turbo:before-cache", () => {
    document.querySelectorAll(".chip-multi-control").forEach((control) => control.remove());
    document.querySelectorAll(".chip-source-select").forEach((select) => {
      select.classList.remove("chip-source-select");
    });
    document.querySelectorAll("*").forEach((element) => {
      Object.keys(element.dataset || {}).forEach((key) => {
        if (key.endsWith("Bound")) delete element.dataset[key];
      });
    });
    document.body.classList.remove("mobile-menu-open");
    document.querySelectorAll("dialog[open]").forEach((dialog) => dialog.close?.());
  }, { once: true });

  document.querySelectorAll("[data-add-farmer-form]").forEach((formShell) => {
    const villageSelect = formShell.querySelector("[data-add-farmer-village]");
    const villageLabelInput = formShell.querySelector("[data-add-farmer-village-label]");
    const targetInput = formShell.querySelector("[data-add-farmer-target]");
    const noFarmerInput = formShell.querySelector("[data-add-farmer-no-farmer]");
    const form = formShell.querySelector("form");
    let mappings = [];

    try {
      mappings = JSON.parse(formShell.dataset.addFarmerMap || "[]");
    } catch (_error) {
      mappings = [];
    }

    const selectedMapping = () => mappings.find((mapping) => String(mapping.id || "") === String(villageSelect?.value || ""));

    const syncAddFarmerTarget = () => {
      const mapping = selectedMapping();
      if (villageLabelInput) villageLabelInput.value = mapping?.label || "";
      if (targetInput) targetInput.value = mapping?.target_quantity || "";
      if (noFarmerInput) noFarmerInput.removeAttribute("max");
    };

    villageSelect?.addEventListener("change", () => {
      syncAddFarmerTarget();
    });

    form?.addEventListener("submit", (event) => {
      const mapping = selectedMapping();
      const noFarmerValue = Number(noFarmerInput?.value || 0);
      if (mapping && Number.isInteger(noFarmerValue) && noFarmerValue > 0) return;

      event.preventDefault();
      window.alert(mapping ? "No. Farmer valid whole number hona chahiye." : "Please select Mapped Village.");
    });

    syncAddFarmerTarget();
  });

  const escapeXlsxXml = (value) => {
    return String(value ?? "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&apos;")
      .replaceAll("\n", "&#10;");
  };

  const xlsxColumnName = (number) => {
    let name = "";
    while (number > 0) {
      number -= 1;
      name = String.fromCharCode(65 + (number % 26)) + name;
      number = Math.floor(number / 26);
    }
    return name || "A";
  };

  const xlsxCellReference = (column, row) => `${xlsxColumnName(column)}${row}`;

  const xlsxRowsXml = (rows) => {
    return rows.map((row, rowIndex) => {
      const rowNumber = rowIndex + 1;
      const cells = row.map((value, columnIndex) => {
        const reference = xlsxCellReference(columnIndex + 1, rowNumber);
        return `<c r="${reference}" t="inlineStr"><is><t>${escapeXlsxXml(value)}</t></is></c>`;
      }).join("");
      return `<row r="${rowNumber}">${cells}</row>`;
    }).join("\n");
  };

  const buildXlsxFiles = (rows, sheetName) => {
    const safeSheetName = (sheetName || "Sheet1").replace(/[\[\]\*\/\\?:]/g, " ").trim().slice(0, 31) || "Sheet1";
    const rowCount = Math.max(rows.length, 1);
    const columnCount = Math.max(...rows.map((row) => row.length), 1);
    const dimension = `A1:${xlsxCellReference(columnCount, rowCount)}`;
    const timestamp = new Date().toISOString();

    return [
      {
        name: "[Content_Types].xml",
        data: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>`
      },
      {
        name: "_rels/.rels",
        data: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>`
      },
      {
        name: "docProps/app.xml",
        data: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"><Application>VRP</Application></Properties>`
      },
      {
        name: "docProps/core.xml",
        data: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:creator>VRP</dc:creator><cp:lastModifiedBy>VRP</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">${timestamp}</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">${timestamp}</dcterms:modified>
</cp:coreProperties>`
      },
      {
        name: "xl/workbook.xml",
        data: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets><sheet name="${escapeXlsxXml(safeSheetName)}" sheetId="1" r:id="rId1"/></sheets>
</workbook>`
      },
      {
        name: "xl/_rels/workbook.xml.rels",
        data: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>`
      },
      {
        name: "xl/styles.xml",
        data: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>
  <fills count="1"><fill><patternFill patternType="none"/></fill></fills>
  <borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
  <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
  <cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>
  <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>`
      },
      {
        name: "xl/worksheets/sheet1.xml",
        data: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <dimension ref="${dimension}"/><sheetViews><sheetView workbookViewId="0"/></sheetViews><sheetFormatPr defaultRowHeight="15"/>
  <sheetData>${xlsxRowsXml(rows)}</sheetData>
</worksheet>`
      }
    ];
  };

  const crcTable = Array.from({ length: 256 }, (_, index) => {
    let value = index;
    for (let bit = 0; bit < 8; bit += 1) value = (value & 1) ? (0xedb88320 ^ (value >>> 1)) : (value >>> 1);
    return value >>> 0;
  });

  const crc32 = (bytes) => {
    let crc = 0xffffffff;
    bytes.forEach((byte) => {
      crc = crcTable[(crc ^ byte) & 0xff] ^ (crc >>> 8);
    });
    return (crc ^ 0xffffffff) >>> 0;
  };

  const appendUint16 = (target, value) => {
    target.push(value & 0xff, (value >>> 8) & 0xff);
  };

  const appendUint32 = (target, value) => {
    target.push(value & 0xff, (value >>> 8) & 0xff, (value >>> 16) & 0xff, (value >>> 24) & 0xff);
  };

  const appendBytes = (target, bytes) => {
    bytes.forEach((byte) => target.push(byte));
  };

  const zipDateParts = () => {
    const now = new Date();
    const time = (now.getHours() << 11) | (now.getMinutes() << 5) | Math.floor(now.getSeconds() / 2);
    const date = ((now.getFullYear() - 1980) << 9) | ((now.getMonth() + 1) << 5) | now.getDate();
    return { time, date };
  };

  const buildZip = (files) => {
    const encoder = new TextEncoder();
    const body = [];
    const centralDirectory = [];
    const { time, date } = zipDateParts();

    files.forEach((file) => {
      const nameBytes = encoder.encode(file.name);
      const dataBytes = encoder.encode(file.data);
      const checksum = crc32(dataBytes);
      const offset = body.length;

      appendUint32(body, 0x04034b50);
      appendUint16(body, 20);
      appendUint16(body, 0x0800);
      appendUint16(body, 0);
      appendUint16(body, time);
      appendUint16(body, date);
      appendUint32(body, checksum);
      appendUint32(body, dataBytes.length);
      appendUint32(body, dataBytes.length);
      appendUint16(body, nameBytes.length);
      appendUint16(body, 0);
      appendBytes(body, nameBytes);
      appendBytes(body, dataBytes);

      appendUint32(centralDirectory, 0x02014b50);
      appendUint16(centralDirectory, 20);
      appendUint16(centralDirectory, 20);
      appendUint16(centralDirectory, 0x0800);
      appendUint16(centralDirectory, 0);
      appendUint16(centralDirectory, time);
      appendUint16(centralDirectory, date);
      appendUint32(centralDirectory, checksum);
      appendUint32(centralDirectory, dataBytes.length);
      appendUint32(centralDirectory, dataBytes.length);
      appendUint16(centralDirectory, nameBytes.length);
      appendUint16(centralDirectory, 0);
      appendUint16(centralDirectory, 0);
      appendUint16(centralDirectory, 0);
      appendUint16(centralDirectory, 0);
      appendUint32(centralDirectory, 0);
      appendUint32(centralDirectory, offset);
      appendBytes(centralDirectory, nameBytes);
    });

    const centralDirectoryOffset = body.length;
    appendBytes(body, centralDirectory);
    appendUint32(body, 0x06054b50);
    appendUint16(body, 0);
    appendUint16(body, 0);
    appendUint16(body, files.length);
    appendUint16(body, files.length);
    appendUint32(body, centralDirectory.length);
    appendUint32(body, centralDirectoryOffset);
    appendUint16(body, 0);

    return new Uint8Array(body);
  };

  const buildXlsxBlob = (rows, sheetName) => {
    const files = buildXlsxFiles(rows.length ? rows : [[""]], sheetName);
    return new Blob([buildZip(files)], { type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" });
  };

  document.querySelectorAll("[data-export-table]").forEach((button) => {
    button.addEventListener("click", () => {
      const table = document.getElementById(button.dataset.exportTable);
      if (!table) return;

      const startColumn = button.dataset.exportIncludeAll === "true" ? 0 : 1;
      const rows = Array.from(table.querySelectorAll("tr")).map((row) => {
        return Array.from(row.children)
          .slice(startColumn)
          .map((cell) => {
            if (Object.prototype.hasOwnProperty.call(cell.dataset, "exportValue")) {
              return String(cell.dataset.exportValue || "").trim();
            }

            const value = cell.matches("th") ? (cell.querySelector(".column-filter-label")?.innerText || cell.innerText) : cell.innerText;
            return value.trim();
          });
      });

      const blob = buildXlsxBlob(rows, button.dataset.exportTable);
      const link = document.createElement("a");
      link.href = URL.createObjectURL(blob);
      link.download = `${button.dataset.exportTable}.xlsx`;
      link.click();
      URL.revokeObjectURL(link.href);
    });
  });

  const paginateTable = (table, page = 1) => {
    const pageSize = Number(table.dataset.pageSize || 15);
    const query = (document.querySelector(`[data-table-search='${table.id}']`)?.value || "").toLowerCase();
    const rows = Array.from(table.querySelectorAll("tbody tr"));
    const dataRows = rows.filter((row) => !row.dataset.emptyRow);
    const columnFilters = JSON.parse(table.dataset.columnFilters || "{}");
    const matchedRows = dataRows.filter((row) => {
      const globalMatch = !query || row.textContent.toLowerCase().includes(query);
      if (!globalMatch) return false;

      return Object.entries(columnFilters).every(([columnIndex, filter]) => {
        const cellText = (row.children[Number(columnIndex)]?.textContent || "").toLowerCase();
        const filterValue = (filter.value || "").toLowerCase();
        if (!filterValue) return true;

        switch (filter.operator) {
          case "equals":
            return cellText === filterValue;
          case "starts":
            return cellText.startsWith(filterValue);
          case "ends":
            return cellText.endsWith(filterValue);
          default:
            return cellText.includes(filterValue);
        }
      });
    });
    const totalPages = Math.max(1, Math.ceil(matchedRows.length / pageSize));
    const currentPage = Math.min(Math.max(page, 1), totalPages);
    const start = (currentPage - 1) * pageSize;
    const visibleRows = matchedRows.slice(start, start + pageSize);

    dataRows.forEach((row) => {
      row.hidden = !visibleRows.includes(row);
    });

    const pagination = document.querySelector(`[data-pagination-for='${table.id}']`);
    if (pagination) {
      pagination.innerHTML = "";

      const summary = document.createElement("span");
      summary.textContent = `${matchedRows.length === 0 ? 0 : start + 1} to ${Math.min(start + pageSize, matchedRows.length)} of ${matchedRows.length}`;
      pagination.appendChild(summary);

      const previous = document.createElement("button");
      previous.type = "button";
      previous.textContent = "‹";
      previous.disabled = currentPage === 1;
      previous.addEventListener("click", () => paginateTable(table, currentPage - 1));
      pagination.appendChild(previous);

      const pageLabel = document.createElement("strong");
      pageLabel.textContent = `Page ${currentPage} of ${totalPages}`;
      pagination.appendChild(pageLabel);

      const next = document.createElement("button");
      next.type = "button";
      next.textContent = "›";
      next.disabled = currentPage === totalPages;
      next.addEventListener("click", () => paginateTable(table, currentPage + 1));
      pagination.appendChild(next);
    }
  };

  const closeColumnFilters = (exceptPanel = null) => {
    document.querySelectorAll(".column-filter-panel.open").forEach((panel) => {
      if (panel !== exceptPanel) panel.classList.remove("open");
    });
  };

  const renderColumnFilterState = (table, header, columnIndex, operator, value) => {
    const filters = JSON.parse(table.dataset.columnFilters || "{}");
    if (value) {
      filters[columnIndex] = { operator, value };
    } else {
      delete filters[columnIndex];
    }

    table.dataset.columnFilters = JSON.stringify(filters);
    header.classList.toggle("filtered", Boolean(value));
    paginateTable(table, 1);
  };

  const setupColumnFilters = (table) => {
    if (table.dataset.columnFiltersReady) return;

    table.dataset.columnFiltersReady = "true";
    table.dataset.columnFilters ||= "{}";

    table.querySelectorAll("thead th").forEach((header, columnIndex) => {
      if (header.querySelector("input[type='checkbox']")) return;
      if (header.querySelector(".column-filter-trigger")) return;

      const label = document.createElement("span");
      label.className = "column-filter-label";
      label.textContent = header.textContent.trim();

      const trigger = document.createElement("button");
      trigger.type = "button";
      trigger.className = "column-filter-trigger";
      trigger.textContent = "≡";
      trigger.setAttribute("aria-label", `Filter ${label.textContent || "column"}`);

      const panel = document.createElement("div");
      panel.className = "column-filter-panel";

      const operator = document.createElement("select");
      operator.innerHTML = `
        <option value="contains">Contains</option>
        <option value="equals">Equals</option>
        <option value="starts">Starts with</option>
        <option value="ends">Ends with</option>
      `;

      const input = document.createElement("input");
      input.type = "search";
      input.placeholder = "Filter...";

      panel.appendChild(operator);
      panel.appendChild(input);
      header.textContent = "";
      header.classList.add("column-filter-header");
      header.appendChild(label);
      header.appendChild(trigger);
      header.appendChild(panel);

      trigger.addEventListener("click", (event) => {
        event.stopPropagation();
        const shouldOpen = !panel.classList.contains("open");
        closeColumnFilters(panel);
        panel.classList.toggle("open", shouldOpen);
        if (shouldOpen) input.focus();
      });

      panel.addEventListener("click", (event) => event.stopPropagation());

      operator.addEventListener("change", () => {
        renderColumnFilterState(table, header, columnIndex, operator.value, input.value.trim());
      });

      input.addEventListener("input", () => {
        renderColumnFilterState(table, header, columnIndex, operator.value, input.value.trim());
      });
    });
  };

  if (!window.__layoutColumnFilterClickBound) {
    window.__layoutColumnFilterClickBound = true;
    document.addEventListener("click", () => closeColumnFilters());
  }

  const ensureTableSearch = (table, index) => {
    if (!table.id) table.id = `auto_paginated_table_${index + 1}`;
    if (document.querySelector(`[data-table-search='${table.id}']`)) return;

    const shell = table.closest(".table-shell") || table;
    const controls = document.createElement("div");
    controls.className = "list-controls auto-list-controls";
    controls.innerHTML = `
      <div class="list-search">
        <span>⌕</span>
        <input type="search" placeholder="Search records" data-table-search="${table.id}">
      </div>
    `;
    shell.insertAdjacentElement("beforebegin", controls);
  };

  const ensureTablePagination = (table) => {
    if (!table.id || document.querySelector(`[data-pagination-for='${table.id}']`)) return;

    const pagination = document.createElement("div");
    pagination.className = "table-pagination";
    pagination.dataset.paginationFor = table.id;
    (table.closest(".table-shell") || table).insertAdjacentElement("afterend", pagination);
  };

  const sortTableRowsAlphabetically = (table) => {
    if (table.dataset.preserveOrder === "true") return;
    if (table.dataset.alphaSorted === "true") return;
    if (table.tBodies[0]?.rows.length > 80) {
      table.dataset.alphaSorted = "true";
      return;
    }

    const tbody = table.tBodies[0];
    if (!tbody) return;

    const rows = Array.from(tbody.rows);
    const dataRows = rows.filter((row) => !row.dataset.emptyRow);
    const emptyRows = rows.filter((row) => row.dataset.emptyRow);
    const meaningfulText = (row) => {
      const cells = Array.from(row.cells).filter((cell) => !cell.querySelector("input[type='checkbox']"));
      const cell = cells.find((candidate) => candidate.innerText.trim()) || cells[0];
      return (cell?.innerText || "").trim();
    };

    dataRows
      .sort((left, right) => meaningfulText(left).localeCompare(meaningfulText(right), undefined, { sensitivity: "base", numeric: true }))
      .forEach((row) => tbody.appendChild(row));
    emptyRows.forEach((row) => tbody.appendChild(row));
    table.dataset.alphaSorted = "true";
  };

  document.querySelectorAll("[data-paginated-table]").forEach((table, index) => {
    const rows = Array.from(table.querySelectorAll("tbody tr"));
    rows.forEach((row) => {
      if (row.children.length === 1 || row.innerText.toLowerCase().includes("no records")) {
        row.dataset.emptyRow = "true";
      }
    });
    const largeTable = table.dataset.fastOpenTable === "true" || rows.length > 250;
    ensureTableSearch(table, index);
    ensureTablePagination(table);
    if (!largeTable) {
      sortTableRowsAlphabetically(table);
      setupColumnFilters(table);
    }
    paginateTable(table, 1);
  });

  document.querySelectorAll("[data-table-search]").forEach((input) => {
    if (input.dataset.tableSearchBound === "true") return;

    input.dataset.tableSearchBound = "true";
    input.addEventListener("input", () => {
      const table = document.getElementById(input.dataset.tableSearch);
      if (table) paginateTable(table, 1);
    });
  });

  // Simple client-side row filter for report tables (Demonstration Method / CC and JJ lists).
  document.querySelectorAll("[data-report-search]").forEach((input) => {
    if (input.dataset.reportSearchBound === "true") return;
    input.dataset.reportSearchBound = "true";
    input.addEventListener("input", () => {
      const query = input.value.trim().toLowerCase();
      const scope = input.closest("section") || document;
      const table = scope.querySelector("[data-report-search-table]") || document.querySelector("[data-report-search-table]");
      if (!table) return;
      table.querySelectorAll("tbody tr").forEach((tr) => {
        tr.style.display = tr.textContent.toLowerCase().includes(query) ? "" : "none";
      });
    });
  });

  document.querySelectorAll("[data-import-file]").forEach((input) => {
    input.addEventListener("change", () => {
      if (!input.files.length) return;

      const label = input.closest(".import-btn");
      if (label) label.firstChild.textContent = input.files[0].name;
    });
  });

  document.querySelectorAll("[data-upload-selected]").forEach((button) => {
    button.addEventListener("click", () => {
      const controls = button.closest(".list-controls") || button.closest(".dashboard-actions");
      const input = controls?.querySelector("[data-import-file]");

      if (!input || !input.files.length) {
        window.alert("Please choose an Excel/CSV file first.");
        return;
      }

      window.alert("Upload file selected. Backend bulk import parser is not connected yet.");
    });
  });

  document.querySelectorAll("[data-chip-multiselect]").forEach((select) => {
    if (select.nextElementSibling?.classList.contains("chip-multi-control")) return;

    const control = document.createElement("div");
    const chips = document.createElement("div");
    const dropdown = document.createElement("div");
    const arrow = document.createElement("span");
    const placeholder = select.dataset.placeholder || "Select";
    const selectAllKey = select.dataset.chipSelectAllKey || select.dataset.locationLevel;
    const selectAllScope = select.closest("[data-target-mapping]") || select.closest("[data-location-form]") || select.form;
    const selectAllCheckbox = selectAllKey
      ? selectAllScope?.querySelector(`[data-chip-select-all-for="${selectAllKey}"]`)
      : null;
    let chipSearchTerm = "";

    control.className = "chip-multi-control";
    chips.className = "chip-multi-values";
    dropdown.className = "chip-multi-dropdown";
    arrow.className = "chip-multi-arrow";
    arrow.textContent = "⌄";
    control.tabIndex = 0;

    select.classList.add("chip-source-select");
    select.insertAdjacentElement("afterend", control);
    control.appendChild(chips);
    control.appendChild(arrow);
    control.appendChild(dropdown);
    dropdown.addEventListener("pointerdown", (event) => event.stopPropagation());
    dropdown.addEventListener("click", (event) => event.stopPropagation());

    const selectableOptions = () => Array.from(select.options)
      .filter((option) => option.value !== "" && !option.disabled && !option.hidden)
      .sort((left, right) => left.textContent.localeCompare(right.textContent, undefined, { sensitivity: "base" }));
    const selectedOptions = () => selectableOptions().filter((option) => option.selected);

    const syncSelectAllCheckbox = () => {
      if (!selectAllCheckbox) return;

      const options = selectableOptions();
      const selected = selectedOptions();
      selectAllCheckbox.disabled = select.disabled || options.length === 0;
      selectAllCheckbox.checked = options.length > 0 && selected.length === options.length;
      selectAllCheckbox.indeterminate = selected.length > 0 && selected.length < options.length;
    };

    const render = (focusSearch = false) => {
      const selected = selectedOptions();
      chips.innerHTML = "";
      dropdown.innerHTML = "";
      control.classList.toggle("disabled", select.disabled);
      control.setAttribute("aria-disabled", select.disabled ? "true" : "false");
      syncSelectAllCheckbox();

      if (!selected.length) {
        const empty = document.createElement("span");
        empty.className = "chip-placeholder";
        empty.textContent = placeholder;
        chips.appendChild(empty);
      }

      const displayedSelections = select.dataset.chipCompactSelection === "true" ? selected.slice(0, 2) : selected;
      displayedSelections.forEach((option) => {
        const chip = document.createElement("button");
        chip.type = "button";
        chip.className = "chip-token";
        chip.innerHTML = `<span>${option.textContent}</span><strong>×</strong>`;
        chip.addEventListener("click", (event) => {
          event.stopPropagation();
          if (select.disabled) return;
          option.selected = false;
          select.dataset.selectionDirty = "true";
          select.dispatchEvent(new Event("change", { bubbles: true }));
          render();
        });
        chips.appendChild(chip);
      });

      if (displayedSelections.length < selected.length) {
        const summary = document.createElement("span");
        summary.className = "chip-selection-summary";
        summary.textContent = `+${selected.length - displayedSelections.length} more selected`;
        chips.appendChild(summary);
      }

      const searchInput = document.createElement("input");
      searchInput.type = "search";
      searchInput.className = "chip-search-input";
      searchInput.placeholder = `Search ${placeholder}`;
      searchInput.value = chipSearchTerm;
      searchInput.disabled = select.disabled;
      searchInput.addEventListener("click", (event) => event.stopPropagation());
      searchInput.addEventListener("keydown", (event) => event.stopPropagation());
      searchInput.addEventListener("input", () => {
        chipSearchTerm = searchInput.value;
        render(true);
        control.classList.add("open");
      });
      dropdown.appendChild(searchInput);

      const options = selectableOptions();
      const normalizedSearch = chipSearchTerm.trim().toLowerCase();
      const visibleOptions = normalizedSearch
        ? options.filter((option) => option.textContent.toLowerCase().includes(normalizedSearch))
        : options;

      if (visibleOptions.length) {
        const selectAllRow = document.createElement("label");
        const selectAllInput = document.createElement("input");
        const selectAllText = document.createElement("span");
        const selectedVisibleCount = visibleOptions.filter((option) => option.selected).length;

        selectAllRow.className = "chip-select-all-option";
        selectAllInput.type = "checkbox";
        selectAllInput.checked = selectedVisibleCount === visibleOptions.length;
        selectAllInput.indeterminate = selectedVisibleCount > 0 && selectedVisibleCount < visibleOptions.length;
        selectAllInput.disabled = select.disabled;
        selectAllText.textContent = normalizedSearch ? "Select all search results" : "Select all";

        selectAllRow.addEventListener("click", (event) => event.stopPropagation());
        selectAllInput.addEventListener("change", () => {
          if (select.disabled) return;

          visibleOptions.forEach((option) => {
            option.selected = selectAllInput.checked;
          });
          select.dataset.selectionDirty = "true";
          select.dispatchEvent(new Event("change", { bubbles: true }));
          render(true);
          control.classList.add("open");
        });
        selectAllRow.appendChild(selectAllInput);
        selectAllRow.appendChild(selectAllText);
        dropdown.appendChild(selectAllRow);
      }

      if (!options.length) {
        const emptyOption = document.createElement("div");
        emptyOption.className = "chip-option empty";
        emptyOption.textContent = "No options saved yet";
        dropdown.appendChild(emptyOption);
      }

      if (options.length > 0 && !visibleOptions.length) {
        const emptyOption = document.createElement("div");
        emptyOption.className = "chip-option empty";
        emptyOption.textContent = "No matching options";
        dropdown.appendChild(emptyOption);
      }

      visibleOptions.forEach((option) => {
        const item = document.createElement("button");
        item.type = "button";
        item.className = "chip-option";
        item.textContent = option.textContent;
        item.dataset.selected = option.selected ? "true" : "false";
        item.disabled = select.disabled;
        item.addEventListener("click", (event) => {
          event.stopPropagation();
          if (select.disabled) return;
          option.selected = !option.selected;
          select.dataset.selectionDirty = "true";
          select.dispatchEvent(new Event("change", { bubbles: true }));
          render();
          control.classList.add("open");
        });
        dropdown.appendChild(item);
      });

      if (focusSearch) {
        window.requestAnimationFrame(() => {
          searchInput.focus();
          searchInput.setSelectionRange(searchInput.value.length, searchInput.value.length);
        });
      }
    };

    selectAllCheckbox?.addEventListener("change", () => {
      if (select.disabled) return;

      selectableOptions().forEach((option) => {
        option.selected = selectAllCheckbox.checked;
      });
      select.dataset.selectionDirty = "true";
      select.dispatchEvent(new Event("change", { bubbles: true }));
      render();
    });
    select.addEventListener("chip:refresh", () => render());

    control.addEventListener("click", (event) => {
      if (select.disabled) return;
      if (event.target.closest(".chip-multi-dropdown")) return;

      document.querySelectorAll(".chip-multi-control.open").forEach((openControl) => {
        if (openControl !== control) openControl.classList.remove("open");
      });
      if (select.dataset.chipHoverOpen === "true") control.classList.add("open");
      else control.classList.toggle("open");
    });

    control.addEventListener("focus", () => {
      if (select.disabled) return;

      control.classList.add("open");
    });

    if (select.dataset.chipHoverOpen === "true") {
      control.addEventListener("pointerenter", () => {
        if (select.disabled) return;

        document.querySelectorAll(".chip-multi-control.open").forEach((openControl) => {
          if (openControl !== control) openControl.classList.remove("open");
        });
        control.classList.add("open");
      });
    }

    control.addEventListener("keydown", (event) => {
      if (event.key !== "Enter" && event.key !== " ") return;

      event.preventDefault();
      control.click();
    });

    select.addEventListener("change", render);
    select.addEventListener("chip:refresh", render);

    render();
  });

  const dashboardSearch = document.querySelector("[data-dashboard-search]");
  if (dashboardSearch) {
    dashboardSearch.addEventListener("input", () => {
      const query = dashboardSearch.value.toLowerCase();
      document.querySelectorAll("[data-dashboard-card]").forEach((card) => {
        card.hidden = !card.innerText.toLowerCase().includes(query);
      });
    });
  }

  const dashboardClockTime = document.querySelector("[data-dashboard-clock-time]");
  const dashboardClockDate = document.querySelector("[data-dashboard-clock-date]");
  if (dashboardClockTime && dashboardClockDate) {
    if (window.dashboardClockTimer) window.clearInterval(window.dashboardClockTimer);

    const renderDashboardClock = () => {
      const now = new Date();
      dashboardClockTime.textContent = now.toLocaleTimeString("en-IN", {
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit"
      });
      dashboardClockDate.textContent = now.toLocaleDateString("en-IN", {
        weekday: "long",
        day: "2-digit",
        month: "long",
        year: "numeric"
      });
    };

    renderDashboardClock();
    window.dashboardClockTimer = window.setInterval(renderDashboardClock, 1000);
  }

  document.querySelectorAll("[data-approval-levels]").forEach((shell) => {
    const table = shell.querySelector("[data-approval-level-table]");
    const addButton = shell.querySelector("[data-add-approval-level]");
    const firstSelect = table?.querySelector("select[name*='[approval_steps]']");
    const approverOptions = firstSelect
      ? Array.from(firstSelect.options).map((option) => ({ value: option.value, label: option.textContent }))
      : [{ value: "", label: "Select approval user" }];
    const approvalLevelLabel = (sequence) => {
      const labels = {
        1: "First Approval",
        2: "Second Approval",
        3: "Third Approval",
        4: "Fourth Approval",
        5: "Fifth Approval",
        6: "Sixth Approval",
        7: "Seventh Approval",
        8: "Eighth Approval",
        9: "Ninth Approval",
        10: "Tenth Approval"
      };
      return labels[sequence] || `Approval ${sequence}`;
    };

    const approvalRowCount = () => new Set(Array.from(table?.querySelectorAll("[data-approval-row]") || []).map((cell) => cell.dataset.approvalRow)).size;

    const removeApprovalRow = (rowIndex) => {
      if (!table || approvalRowCount() <= 1) return;

      table.querySelectorAll(`[data-approval-row="${rowIndex}"]`).forEach((cell) => cell.remove());
    };

    const addApprovalRow = () => {
      if (!table) return;

      const rowIndex = Number(shell.dataset.nextApprovalLevel || approvalRowCount() + 1);
      const level = approvalLevelLabel(rowIndex);
      const rowKey = `new_${Date.now()}_${rowIndex}`;
      shell.dataset.nextApprovalLevel = String(rowIndex + 1);

      const levelCell = document.createElement("div");
      levelCell.className = "approval-level-cell";
      levelCell.dataset.approvalRow = rowKey;
      levelCell.innerHTML = `<strong>${level}</strong><small>Approval step ${rowIndex}</small>`;

      const userCell = document.createElement("div");
      userCell.className = "approval-level-cell";
      userCell.dataset.approvalRow = rowKey;
      const recordIdInput = document.createElement("input");
      recordIdInput.type = "hidden";
      recordIdInput.name = `module_record[approval_steps][${rowKey}][record_id]`;
      userCell.appendChild(recordIdInput);
      const levelInput = document.createElement("input");
      levelInput.type = "hidden";
      levelInput.name = `module_record[approval_steps][${rowKey}][approval_level]`;
      levelInput.value = level;
      userCell.appendChild(levelInput);
      const select = document.createElement("select");
      select.name = `module_record[approval_steps][${rowKey}][approver_approved_by]`;
      approverOptions.forEach((optionData) => {
        const option = document.createElement("option");
        option.value = optionData.value;
        option.textContent = optionData.label;
        select.appendChild(option);
      });
      userCell.appendChild(select);
      const hint = document.createElement("small");
      hint.textContent = "Select the user responsible at this approval stage.";
      userCell.appendChild(hint);

      const actionCell = document.createElement("div");
      actionCell.className = "approval-level-cell";
      actionCell.dataset.approvalRow = rowKey;
      const removeButton = document.createElement("button");
      removeButton.type = "button";
      removeButton.className = "remove-level-btn";
      removeButton.dataset.removeApprovalLevel = "true";
      removeButton.textContent = "Remove";
      actionCell.appendChild(removeButton);

      table.appendChild(levelCell);
      table.appendChild(userCell);
      table.appendChild(actionCell);
    };

    addButton?.addEventListener("click", addApprovalRow);

    table?.addEventListener("click", (event) => {
      const button = event.target.closest("[data-remove-approval-level]");
      if (!button) return;

      removeApprovalRow(button.closest("[data-approval-row]")?.dataset.approvalRow);
    });
  });

  document.querySelectorAll("[data-user-hierarchy-levels]").forEach((shell) => {
    const table = shell.querySelector("[data-user-hierarchy-table]");
    const addButton = shell.querySelector("[data-add-user-row]");
    const firstSelect = table?.querySelector("[data-user-row] select");
    const userOptions = firstSelect
      ? Array.from(firstSelect.options).map((option) => ({ value: option.value, label: option.textContent }))
      : [{ value: "", label: "Select Subordinates" }];

    const rowCount = () => new Set(Array.from(table?.querySelectorAll("[data-user-row]") || []).map((cell) => cell.dataset.userRow)).size;

    const removeUserRow = (rowIndex) => {
      if (!table || rowCount() <= 1) return;

      table.querySelectorAll(`[data-user-row="${rowIndex}"]`).forEach((cell) => cell.remove());
    };

    const buildUserSelect = (name, prompt) => {
      const select = document.createElement("select");
      select.name = name;
      userOptions.forEach((optionData, index) => {
        const option = document.createElement("option");
        option.value = optionData.value;
        option.textContent = index === 0 && !optionData.value ? prompt : optionData.label;
        select.appendChild(option);
      });
      return select;
    };

    const addUserRow = () => {
      if (!table) return;

      const rowIndex = Number(shell.dataset.nextUserRow || rowCount() + 1);
      shell.dataset.nextUserRow = String(rowIndex + 1);

      const levelCell = document.createElement("div");
      levelCell.className = "approval-level-cell";
      levelCell.dataset.userRow = String(rowIndex);
      levelCell.innerHTML = `<strong>Level 2</strong><small>User ${rowIndex}</small>`;

      const userCell = document.createElement("div");
      userCell.className = "approval-level-cell";
      userCell.dataset.userRow = String(rowIndex);
      userCell.appendChild(buildUserSelect(`module_record[level_2_mappings][${rowIndex}][level_2_user]`, "Select Subordinates"));

      const actionCell = document.createElement("div");
      actionCell.className = "approval-level-cell";
      actionCell.dataset.userRow = String(rowIndex);
      const removeButton = document.createElement("button");
      removeButton.type = "button";
      removeButton.className = "remove-level-btn";
      removeButton.dataset.removeUserRow = "true";
      removeButton.textContent = "Remove";
      actionCell.appendChild(removeButton);

      table.appendChild(levelCell);
      table.appendChild(userCell);
      table.appendChild(actionCell);
    };

    addButton?.addEventListener("click", addUserRow);

    table?.addEventListener("click", (event) => {
      const button = event.target.closest("[data-remove-user-row]");
      if (!button) return;

      removeUserRow(button.closest("[data-user-row]")?.dataset.userRow);
    });

  });

  const approvalModal = document.querySelector("[data-approval-modal]");
  const approvalModalForm = document.querySelector("[data-approval-modal-form]");
  const approvalModalTitle = document.querySelector("[data-approval-modal-title]");
  const approvalModalSubmit = document.querySelector("[data-approval-modal-submit]");
  const approvalRemarks = approvalModal?.querySelector("textarea[name='remarks']");
  let approvalSourceRow = null;

  document.querySelectorAll("[data-open-approval-modal]").forEach((button) => {
    button.addEventListener("click", () => {
      if (!approvalModal || !approvalModalForm) return;

      const action = button.dataset.approvalAction || "approve";
      approvalSourceRow = button.closest("[data-bill-list-row]");
      approvalModalForm.action = button.dataset.approvalUrl;
      const isReturn = action === "return";
      const isReject = action === "reject";
      if (approvalModalTitle) {
        approvalModalTitle.textContent = isReturn ? "Return Remarks" : (isReject ? "Rejection Remarks" : "Approval Remarks");
      }
      if (approvalModalSubmit) {
        approvalModalSubmit.textContent = isReturn ? "Return" : (isReject ? "Reject" : "Approve");
        approvalModalSubmit.classList.toggle("deactive", isReject || isReturn);
        approvalModalSubmit.classList.toggle("active", !(isReject || isReturn));
      }
      if (approvalRemarks) approvalRemarks.value = "";

      if (typeof approvalModal.showModal === "function") {
        approvalModal.showModal();
      } else {
        approvalModal.setAttribute("open", "open");
      }
    });
  });

  document.querySelectorAll("[data-close-approval-modal]").forEach((button) => {
    button.addEventListener("click", () => {
      if (!approvalModal) return;

      if (typeof approvalModal.close === "function") {
        approvalModal.close();
      } else {
        approvalModal.removeAttribute("open");
      }
    });
  });

  approvalModalForm?.addEventListener("submit", async (event) => {
    if (!approvalSourceRow || !document.querySelector("[data-bill-list-filters]")) return;

    event.preventDefault();
    if (approvalModalSubmit) approvalModalSubmit.disabled = true;

    try {
      const response = await fetch(approvalModalForm.action, {
        method: approvalModalForm.method || "POST",
        body: new FormData(approvalModalForm),
        credentials: "same-origin",
        headers: {
          "X-CSRF-Token": csrfToken,
          Accept: "application/json"
        }
      });
      const contentType = response.headers.get("content-type") || "";
      if (!response.ok || !contentType.includes("application/json")) {
        throw new Error("Approval could not be saved.");
      }

      const result = await response.json();
      if (!result.ok) throw new Error(result.message || "Approval could not be saved.");

      approvalSourceRow.remove();
      if (typeof approvalModal.close === "function") approvalModal.close();
      const table = document.getElementById("jeevika_jankar_bill_table");
      if (table) paginateTable(table, 1);
      approvalSourceRow = null;
    } catch (error) {
      window.alert(error.message || "Approval could not be saved.");
    } finally {
      if (approvalModalSubmit) approvalModalSubmit.disabled = false;
    }
  });

  document.querySelectorAll("[data-jeevika-payment-detail]").forEach((paymentForm) => {
    const dateSelect = paymentForm.querySelector("[data-payment-date-select]");
    const rows = Array.from(paymentForm.querySelectorAll("[data-payment-user-row]"));
    const checkboxes = Array.from(paymentForm.querySelectorAll("[data-payment-user-checkbox]"));
    const selectAllButton = paymentForm.querySelector("[data-payment-select-all]");
    const selectAllCheckbox = paymentForm.querySelector("[data-payment-select-all-checkbox]");
    const clearButton = paymentForm.querySelector("[data-payment-clear-selection]");
    const selectedCountInput = paymentForm.querySelector("[data-payment-selected-count]");
    const totalAmountInput = paymentForm.querySelector("[data-payment-total-amount]");
    const submitButton = paymentForm.querySelector("button[type='submit']");

    const money = (value) => value.toFixed(2);
    const selectedDate = () => String(dateSelect?.value || "");
    const rowMatchesSelectedDate = (row) => selectedDate() && row.dataset.paymentBillDate === selectedDate();
    const selectableRows = () => rows.filter(rowMatchesSelectedDate);
    const selectableCheckboxes = () => selectableRows()
      .map((row) => row.querySelector("[data-payment-user-checkbox]"))
      .filter((checkbox) => checkbox && !checkbox.disabled);

    const recalculatePaymentTotal = () => {
      const activeCheckboxes = selectableCheckboxes();
      const checkedCheckboxes = activeCheckboxes.filter((checkbox) => checkbox.checked);
      const checkedCount = checkedCheckboxes.length;
      const selectedAmount = checkedCheckboxes.reduce((total, checkbox) => {
        const row = checkbox.closest("[data-payment-user-row]");
        return total + (Number(row?.dataset.paymentAmount || "0") || 0);
      }, 0);
      if (selectedCountInput) selectedCountInput.value = String(checkedCount);
      if (totalAmountInput) totalAmountInput.value = money(selectedAmount);
      if (submitButton) submitButton.disabled = checkedCount === 0;
      if (clearButton) clearButton.disabled = checkedCount === 0;
      if (selectAllButton) selectAllButton.disabled = activeCheckboxes.length === 0;
      if (selectAllCheckbox) {
        selectAllCheckbox.disabled = activeCheckboxes.length === 0;
        selectAllCheckbox.checked = activeCheckboxes.length > 0 && checkedCount === activeCheckboxes.length;
        selectAllCheckbox.indeterminate = checkedCount > 0 && checkedCount < activeCheckboxes.length;
      }
    };

    const syncPaymentRows = () => {
      const date = selectedDate();

      rows.forEach((row) => {
        const matches = date && row.dataset.paymentBillDate === date;
        row.style.display = matches ? "" : "none";
        const checkbox = row.querySelector("[data-payment-user-checkbox]");
        if (!checkbox) return;

        checkbox.disabled = !matches;
        checkbox.checked = false;
      });

      recalculatePaymentTotal();
    };

    checkboxes.forEach((checkbox) => {
      checkbox.addEventListener("change", recalculatePaymentTotal);
    });

    const setAllPaymentRows = (checked) => {
      selectableCheckboxes().forEach((checkbox) => {
        checkbox.checked = checked;
      });
      recalculatePaymentTotal();
    };

    selectAllButton?.addEventListener("click", () => {
      if (!selectedDate()) {
        window.alert("Approval Date select karein.");
        dateSelect?.focus();
        return;
      }

      setAllPaymentRows(true);
    });

    selectAllCheckbox?.addEventListener("change", () => {
      if (!selectedDate()) {
        selectAllCheckbox.checked = false;
        window.alert("Approval Date select karein.");
        dateSelect?.focus();
        return;
      }

      setAllPaymentRows(selectAllCheckbox.checked);
    });

    clearButton?.addEventListener("click", () => {
      setAllPaymentRows(false);
    });

    paymentForm.querySelector("form")?.addEventListener("submit", (event) => {
      const checkedCount = selectableCheckboxes().filter((checkbox) => checkbox.checked).length;
      if (checkedCount > 0) return;

      event.preventDefault();
      window.alert(dateSelect?.value ? "Kam se kam ek Jeevika Jankar select karein." : "Approval Date select karein.");
    });

    dateSelect?.addEventListener("change", syncPaymentRows);
    syncPaymentRows();
  });

  document.querySelectorAll("[data-jeevika-jankar-bill]").forEach((billForm) => {
    const vrpSelect = billForm.querySelector("[data-jeevika-vrp-select]");
    const monthSelect = billForm.querySelector("[data-jeevika-month-select]");
    const rowsBody = billForm.querySelector("[data-jeevika-bill-rows]");
    const totalTargetInput = billForm.querySelector("[data-jeevika-total-target]");
    const totalAchievementInput = billForm.querySelector("[data-jeevika-total-achievement]");
    const grandTotalInput = billForm.querySelector("[data-jeevika-grand-total]");
    const paymentRemarksField = billForm.querySelector("[data-jeevika-payment-remarks]");
    const paymentRemarksInput = billForm.querySelector("[data-jeevika-payment-remarks-input]");
    const billRowsUrl = billForm.dataset.billRowsUrl;
    let billRows = [];
    let savedItems = [];
    let existingBills = [];
    let achievementSummary = {};
    let targetSummary = {};
    const billRowsCache = new Map();
    let activeBillRowsKey = "";
    const initialVrpValue = String(vrpSelect?.value || "");

    try {
      billRows = JSON.parse(billForm.dataset.billRows || "[]");
      savedItems = JSON.parse(billForm.dataset.savedItems || "[]");
      existingBills = JSON.parse(billForm.dataset.existingBills || "[]");
      achievementSummary = JSON.parse(billForm.dataset.achievementSummary || "{}");
      targetSummary = JSON.parse(billForm.dataset.targetSummary || "{}");
    } catch (_error) {
      billRows = [];
      savedItems = [];
      existingBills = [];
      achievementSummary = {};
      targetSummary = {};
    }

    const escapeHtml = (value) => String(value ?? "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");

    const numberValue = (value) => Number(String(value || "0").replaceAll(",", "")) || 0;
    const syncPaymentRemarks = () => {
      const payment = numberValue(grandTotalInput?.value);
      const requiresRemarks = payment > 0 && Math.abs(payment - 5000) > 0.005;
      if (paymentRemarksField) paymentRemarksField.hidden = !requiresRemarks;
      if (paymentRemarksInput) paymentRemarksInput.required = requiresRemarks;
    };
    const savedItemFor = (row) => savedItems.find((item) => {
      const sameTarget = String(item.target_mapping_id || "") === String(row.target_mapping_id || "");
      const rowSession = String(row.training_session_key || "");
      const itemSession = String(item.training_session_key || "");
      return sameTarget && (!rowSession || rowSession === itemSession);
    }) || {};
    const rowInputs = () => Array.from(rowsBody?.querySelectorAll("tr[data-bill-row]") || []);
    const normalizedChoice = (value) => String(value || "").trim().toLowerCase().replaceAll(" ", "_");
    const normalizedMonth = (value) => String(value || "").trim().toLowerCase();
    const billRowsKey = (vrpId, month) => `${String(vrpId || "").trim()}|${normalizedMonth(month)}`;
    const selectedVrpValue = () => {
      const value = String(vrpSelect?.value || "").trim();
      if (value) return value;

      const selectedOption = vrpSelect?.selectedOptions?.[0];
      const optionText = String(selectedOption?.textContent || "").trim();
      const matchingOption = originalVrpOptions.find((option) => option.label === optionText);
      return String(selectedOption?.dataset?.vrpId || matchingOption?.value || selectedOption?.value || optionText).trim();
    };
    if (!billForm.dataset.originalVrpOptions) {
      const options = Array.from(vrpSelect?.options || [])
        .filter((option) => option.value)
        .map((option) => ({ value: option.value, label: option.textContent }));
      if (options.length) {
        billForm.dataset.originalVrpOptions = JSON.stringify(options);
      }
    }
    const originalVrpOptions = JSON.parse(billForm.dataset.originalVrpOptions || "[]");
    const billExistsFor = (vrpId, month) => {
      const monthKey = normalizedMonth(month);
      return existingBills.some((bill) => String(bill.vrp_id || "") === String(vrpId || "") && normalizedMonth(bill.month) === monthKey);
    };
    const rowAchievementMode = (row) => normalizedChoice(row.achievement_entry_mode) === "self" ? "self" : "auto_fill";
    const rowMainActivityType = (row) => normalizedChoice(row.main_activity_type) === "other" ? "other" : "training";
    const automaticAchievementFor = (row, mainActivityType = rowMainActivityType(row)) => {
      return mainActivityType === "other" ? (row.other_activity_count ?? 0) : (row.achievement_count ?? 0);
    };
    const selectedAchievementTotal = () => {
      const selectedVrp = selectedVrpValue();
      const selectedMonth = normalizedMonth(monthSelect?.value);
      if (!selectedVrp) return null;

      const total = selectedMonth ? achievementSummary?.[selectedVrp]?.[selectedMonth] : achievementSummary?.[selectedVrp]?.__all;
      return total === undefined || total === null ? null : numberValue(total);
    };

    const syncJeevikaVrpOptions = () => {
      if (!vrpSelect) return;

      const selectedMonth = monthSelect?.value || "";
      const previousValue = vrpSelect.value;
      vrpSelect.innerHTML = "";

      const blank = document.createElement("option");
      blank.value = "";
      blank.textContent = selectedMonth ? "Select Jeevika Jankar Name" : "Select Bill Month first";
      vrpSelect.appendChild(blank);

      if (!selectedMonth) {
        vrpSelect.value = "";
        vrpSelect.disabled = true;
        return;
      }

      const availableOptions = originalVrpOptions.filter((option) => {
        if (initialVrpValue && String(option.value) === initialVrpValue) return true;
        return !billExistsFor(option.value, selectedMonth);
      });
      availableOptions.forEach((optionData) => {
        const option = document.createElement("option");
        option.value = optionData.value;
        option.dataset.vrpId = optionData.value;
        option.textContent = optionData.label;
        vrpSelect.appendChild(option);
      });

      vrpSelect.disabled = false;
      if (availableOptions.some((option) => option.value === previousValue)) {
        vrpSelect.value = previousValue;
      } else if (initialVrpValue && availableOptions.some((option) => String(option.value) === initialVrpValue)) {
        vrpSelect.value = initialVrpValue;
      } else {
        vrpSelect.value = "";
      }

      if (!availableOptions.length) {
        blank.textContent = "Selected month ke liye sabhi bills ban chuke hain";
      }
    };

    const farmerDetailsHtml = (farmers) => {
      if (!farmers?.length) return "<div class=\"jeevika-farmer-empty\">No target farmer list saved for this target.</div>";

      const rows = farmers.map((farmer) => `
        <tr>
          <td>${escapeHtml(farmer.name)}</td>
          <td>${escapeHtml(farmer.father_name || "-")}</td>
          <td>${escapeHtml(farmer.mobile_no || "-")}</td>
          <td>${escapeHtml(farmer.department || "-")}</td>
          <td>${escapeHtml(farmer.training_topic || "-")}</td>
          <td>${escapeHtml(farmer.training_subject || "-")}</td>
          <td>${escapeHtml(farmer.training_date || "-")}</td>
        </tr>
      `).join("");

      return `
        <div class="jeevika-farmer-detail">
          <table class="module-table">
            <thead>
              <tr>
                <th>Farmer</th>
                <th>Father</th>
                <th>Mobile</th>
                <th>Department</th>
                <th>Main Activity</th>
                <th>Sub Activity</th>
                <th>Date</th>
              </tr>
            </thead>
            <tbody>${rows}</tbody>
          </table>
        </div>
      `;
    };

    const hiddenInput = (name, value) => `<input type="hidden" name="${name}" value="${escapeHtml(value)}">`;

    const recalculateJeevikaBill = () => {
      let totalTarget = 0;
      let totalAchievement = 0;
      let grandTotal = 0;
      const totalsByTarget = new Map();
      rowInputs().forEach((row) => {
        const target = numberValue(row.dataset.targetQuantity);
        const assigned = numberValue(row.dataset.assignedCount);
        const achievementInput = row.querySelector("[data-jeevika-achievement]");
        const manualAchievement = row.dataset.achievementEntryMode === "self";
        const achievement = manualAchievement ? numberValue(achievementInput?.value) : numberValue(row.dataset.achievementCount);
        const pendingBase = row.dataset.mainActivityType === "other" ? target : (assigned > 0 ? assigned : target);
        const pending = Math.max(pendingBase - achievement, 0);
        const rate = numberValue(row.querySelector("[data-jeevika-rate]")?.value);
        const amount = achievement * rate;
        const amountInput = row.querySelector("[data-jeevika-amount]");
        const achievementDisplay = row.querySelector("[data-jeevika-achievement-display]");
        const pendingDisplay = row.querySelector("[data-jeevika-pending-display]");
        const pendingInput = row.querySelector("[data-jeevika-pending-input]");
        const farmerSummaryCount = row.nextElementSibling?.querySelector("[data-jeevika-farmer-achievement]");

        const targetKey = row.dataset.targetMappingId || `row-${row.dataset.rowIndex || totalsByTarget.size}`;
        const groupedTotal = totalsByTarget.get(targetKey) || { target: 0, achievement: 0 };
        groupedTotal.target = Math.max(groupedTotal.target, pendingBase);
        groupedTotal.achievement += achievement;
        totalsByTarget.set(targetKey, groupedTotal);
        grandTotal += amount;
        row.dataset.currentAchievement = String(achievement);
        if (achievementDisplay) achievementDisplay.textContent = String(achievement);
        if (pendingDisplay) pendingDisplay.textContent = String(pending);
        if (pendingInput) pendingInput.value = String(pending);
        if (farmerSummaryCount) farmerSummaryCount.textContent = String(achievement);
        if (amountInput) amountInput.value = amount.toFixed(2);
      });

      totalsByTarget.forEach((groupedTotal) => {
        totalTarget += groupedTotal.target;
        totalAchievement += Math.min(groupedTotal.achievement, groupedTotal.target);
      });

      if (totalsByTarget.size === 0) {
        const selectedVrp = selectedVrpValue();
        const selectedMonth = normalizedMonth(monthSelect?.value);
        const dashboardTotals = selectedVrp && selectedMonth ? targetSummary?.[selectedVrp]?.[selectedMonth] : null;
        if (dashboardTotals) {
          totalTarget = numberValue(dashboardTotals.target);
          totalAchievement = numberValue(dashboardTotals.achievement);
        }
      }

      if (totalTargetInput) totalTargetInput.value = String(totalTarget);
      if (totalAchievementInput) totalAchievementInput.value = String(totalAchievement);
      // Total Payment is a fixed/manual amount (₹5000 default), not derived from the
      // removed Rate/Amount columns, so it is no longer auto-overwritten here.
      syncPaymentRemarks();
    };

    const loadBillRowsForSelection = async (selectedVrp, selectedMonth) => {
      const key = billRowsKey(selectedVrp, selectedMonth);
      if (billRowsCache.has(key)) return billRowsCache.get(key);

      const inlineRows = billRows.filter((row) => {
        const vrpMatches = String(row.vrp_id || "") === String(selectedVrp || "");
        const monthMatches = normalizedMonth(row.month_name) === normalizedMonth(selectedMonth);
        return vrpMatches && monthMatches;
      });
      if (inlineRows.length || !billRowsUrl) {
        const result = { rows: inlineRows, achievementSummary, targetSummary };
        billRowsCache.set(key, result);
        return result;
      }

      const url = new URL(billRowsUrl, window.location.origin);
      url.searchParams.set("vrp_id", selectedVrp);
      url.searchParams.set("month", selectedMonth);
      const data = await fetchJson(url.toString());
      const result = {
        rows: Array.isArray(data.rows) ? data.rows : [],
        achievementSummary: data.achievement_summary || {},
        targetSummary: data.target_summary || {}
      };
      billRowsCache.set(key, result);
      return result;
    };

    const renderJeevikaBillRows = async () => {
      if (!rowsBody) return;

      const selectedVrp = selectedVrpValue();
      const selectedMonthValue = monthSelect?.value || "";
      const selectedMonth = normalizedMonth(selectedMonthValue);

      if (!selectedMonth) {
        rowsBody.innerHTML = `<tr data-empty-bill-row><td colspan="9">Select Bill Month to load Jeevika Jankar Name.</td></tr>`;
        recalculateJeevikaBill();
        return;
      }

      if (!selectedVrp) {
        if (vrpSelect) vrpSelect.selectedIndex = 0;
        rowsBody.innerHTML = `<tr data-empty-bill-row><td colspan="9">Select Jeevika Jankar Name to load target achievement list.</td></tr>`;
        recalculateJeevikaBill();
        return;
      }

      const loadKey = billRowsKey(selectedVrp, selectedMonthValue);
      activeBillRowsKey = loadKey;
      rowsBody.innerHTML = `<tr data-empty-bill-row><td colspan="9">Loading target achievement list...</td></tr>`;

      let loadedData = { rows: [] };
      try {
        loadedData = await loadBillRowsForSelection(selectedVrp, selectedMonthValue);
      } catch (_error) {
        if (activeBillRowsKey === loadKey) {
          rowsBody.innerHTML = `<tr data-empty-bill-row><td colspan="9">Target achievement list load failed. Please try again.</td></tr>`;
          recalculateJeevikaBill();
        }
        return;
      }
      if (activeBillRowsKey !== loadKey) return;

      const rows = loadedData.rows || [];
      achievementSummary = loadedData.achievementSummary || achievementSummary || {};
      targetSummary = loadedData.targetSummary || targetSummary || {};

      if (!rows.length) {
        rowsBody.innerHTML = `<tr data-empty-bill-row><td colspan="9">No target mapping found for selected Jeevika Jankar.</td></tr>`;
        recalculateJeevikaBill();
        return;
      }

      rowsBody.innerHTML = rows.map((row, index) => {
        const savedItem = savedItemFor(row);
        const rate = savedItem.rate || "0.00";
        const farmerDetails = JSON.stringify(row.farmer_details || []);
        const inputPrefix = `module_record[bill_items][${index}]`;
        const mainActivityType = rowMainActivityType(row);
        const achievementEntryMode = rowAchievementMode(row);
        const manualAchievement = achievementEntryMode === "self";
        const autoAchievementCount = automaticAchievementFor(row, mainActivityType);
        const achievementCount = manualAchievement ? (savedItem.achievement_count ?? autoAchievementCount) : autoAchievementCount;
        const assignedCount = row.assigned_count ?? 0;
        const pendingBase = mainActivityType === "other" ? row.target_quantity : assignedCount;
        const pendingCount = Math.max(numberValue(pendingBase) - numberValue(achievementCount), 0);

        return `
          <tr data-bill-row data-row-index="${index}" data-target-mapping-id="${escapeHtml(row.target_mapping_id || row.training_session_key || index)}" data-target-quantity="${escapeHtml(row.target_quantity)}" data-assigned-count="${escapeHtml(assignedCount)}" data-achievement-count="${escapeHtml(autoAchievementCount)}" data-current-achievement="${escapeHtml(achievementCount)}" data-main-activity-type="${escapeHtml(mainActivityType)}" data-achievement-entry-mode="${escapeHtml(achievementEntryMode)}">
            <td>
              ${hiddenInput(`${inputPrefix}[target_mapping_id]`, row.target_mapping_id)}
              ${hiddenInput(`${inputPrefix}[training_session_key]`, row.training_session_key || "")}
              ${hiddenInput(`${inputPrefix}[vrp_id]`, row.vrp_id)}
              ${hiddenInput(`${inputPrefix}[vrp_name]`, row.vrp_name)}
              ${hiddenInput(`${inputPrefix}[month_name]`, row.month_name)}
              ${hiddenInput(`${inputPrefix}[fco]`, row.fco)}
              ${hiddenInput(`${inputPrefix}[ics]`, row.ics)}
              ${hiddenInput(`${inputPrefix}[village]`, row.village)}
              ${hiddenInput(`${inputPrefix}[main_activity]`, row.main_activity)}
              ${hiddenInput(`${inputPrefix}[activity]`, row.activity)}
              ${hiddenInput(`${inputPrefix}[main_activity_type]`, row.main_activity_type || mainActivityType)}
              ${hiddenInput(`${inputPrefix}[achievement_entry_mode]`, row.achievement_entry_mode || achievementEntryMode)}
              ${hiddenInput(`${inputPrefix}[target_quantity]`, row.target_quantity)}
              ${hiddenInput(`${inputPrefix}[assigned_count]`, assignedCount)}
              ${manualAchievement ? "" : hiddenInput(`${inputPrefix}[achievement_count]`, achievementCount)}
              <input type="hidden" name="${inputPrefix}[pending_count]" value="${escapeHtml(pendingCount)}" data-jeevika-pending-input>
              ${hiddenInput(`${inputPrefix}[same_activity_count]`, row.same_activity_count)}
              ${hiddenInput(`${inputPrefix}[other_activity_count]`, row.other_activity_count)}
              ${hiddenInput(`${inputPrefix}[timesheet_dates]`, row.timesheet_dates)}
              ${hiddenInput(`${inputPrefix}[farmer_details]`, farmerDetails)}
              ${escapeHtml(row.ics || "-")}
            </td>
            <td>${escapeHtml(row.village || "-")}</td>
            <td>${escapeHtml(row.main_activity || "-")}</td>
            <td>${escapeHtml(row.activity || "-")}</td>
            <td>${escapeHtml(row.target_quantity || 0)}</td>
            <td>
              ${manualAchievement
                ? `<input type="number" min="0" step="any" name="${inputPrefix}[achievement_count]" value="${escapeHtml(achievementCount)}" data-jeevika-achievement>`
                : `<span data-jeevika-achievement-display>${escapeHtml(achievementCount)}</span>`}
            </td>
            <td><span data-jeevika-pending-display>${escapeHtml(pendingCount)}</span>
              <input type="hidden" name="${inputPrefix}[rate]" value="${escapeHtml(rate)}" data-jeevika-rate>
              <input type="hidden" name="${inputPrefix}[amount]" value="${escapeHtml(savedItem.amount || "0.00")}" data-jeevika-amount>
            </td>
          </tr>
          <tr class="jeevika-farmer-row">
            <td colspan="7">
              <details class="jeevika-farmer-details">
                <summary data-jeevika-farmer-summary="${index}">Farmer List <span data-jeevika-farmer-achievement>${escapeHtml(achievementCount)}</span> / ${escapeHtml(assignedCount)}</summary>
                ${farmerDetailsHtml(row.farmer_details || [])}
              </details>
            </td>
          </tr>
        `;
      }).join("");

      recalculateJeevikaBill();
    };

    rowsBody?.addEventListener("input", (event) => {
      if (event.target.matches("[data-jeevika-rate], [data-jeevika-achievement]")) recalculateJeevikaBill();
    });
    grandTotalInput?.addEventListener("input", syncPaymentRemarks);
    billForm.querySelector("form")?.addEventListener("submit", (event) => {
      if (rowInputs().length > 0) return;

      event.preventDefault();
      window.alert(monthSelect?.value ? "Please select Jeevika Jankar Name with target mapping." : "Please select Bill Month first.");
    });
    vrpSelect?.addEventListener("change", renderJeevikaBillRows);
    monthSelect?.addEventListener("change", () => {
      syncJeevikaVrpOptions();
      renderJeevikaBillRows();
    });
    syncJeevikaVrpOptions();
    renderJeevikaBillRows();
    syncPaymentRemarks();
  });

  document.querySelectorAll("[data-vrp-bill-form]").forEach((billForm) => {
    const activityMap = JSON.parse(billForm.dataset.activityMap || "{}");
    const tciMap = JSON.parse(billForm.dataset.tciMap || "{}");
    const villageOptions = JSON.parse(billForm.dataset.villageOptions || "[]");
    const icsSelect = billForm.querySelector("[data-bill-ics-select]");
    const groupSelect = billForm.querySelector("[data-bill-activity-group]");
    const activityShell = billForm.querySelector("[data-bill-activity-shell]");
    const rowsBody = billForm.querySelector("[data-bill-activity-rows]");
    const grandUnits = billForm.querySelector("[data-grand-units]");
    const grandTotal = billForm.querySelector("[data-grand-total]");
    const tciModal = billForm.querySelector("[data-tci-modal]");
    const tciRows = billForm.querySelector("[data-tci-modal-rows]");
    let activeTciInput = null;
    let activeTciActivity = "";

    const escapeHtml = (value) => String(value || "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");

    const optionHtml = (options, selected = "") => {
      return options.map((option) => {
        const value = typeof option === "string" ? option : option.indicator;
        const isSelected = value === selected ? " selected" : "";
        return `<option value="${escapeHtml(value)}"${isSelected}>${escapeHtml(value)}</option>`;
      }).join("");
    };

    const recalculateBill = () => {
      let unitsTotal = 0;
      let amountTotal = 0;

      rowsBody?.querySelectorAll("tr:not([data-empty-bill-row])").forEach((row) => {
        const units = Number(row.querySelector("[data-bill-units]")?.value || 0);
        const rate = Number(row.querySelector("[data-bill-rate]")?.value || 0);
        const totalInput = row.querySelector("[data-bill-total]");
        const total = units * rate;

        unitsTotal += units;
        amountTotal += total;
        if (totalInput) totalInput.value = total.toFixed(2);
      });

      if (grandUnits) grandUnits.value = unitsTotal;
      if (grandTotal) grandTotal.value = amountTotal.toFixed(2);
    };

    const selectedValues = (select) => Array.from(select?.selectedOptions || []).map((option) => option.value).filter(Boolean);
    const selectedGroups = () => selectedValues(groupSelect);
    const selectedIcs = () => selectedValues(icsSelect);
    const normalizedActivityKey = (groupName) => {
      const normalizedGroup = String(groupName || "").trim().toLowerCase();
      return Object.keys(activityMap).find((key) => String(key || "").trim().toLowerCase() === normalizedGroup) || groupName;
    };

    const syncActivityGroupState = () => {
      if (!groupSelect || !icsSelect) return;

      const hasIcs = selectedIcs().length > 0;

      if (!hasIcs) {
        buildActivityRows([]);
      }

      groupSelect.dispatchEvent(new Event("chip:refresh"));
    };

    const buildActivityRows = (groupNames) => {
      if (!rowsBody) return;

      if (!groupNames.length) {
        if (activityShell) activityShell.hidden = true;
        rowsBody.innerHTML = "";
        recalculateBill();
        return;
      }

      if (activityShell) activityShell.hidden = false;
      const activities = groupNames.flatMap((groupName) => activityMap[normalizedActivityKey(groupName)] || []);
      rowsBody.innerHTML = "";

      if (activities.length === 0) {
        rowsBody.innerHTML = `<tr data-empty-bill-row><td colspan="6">No activity mapped for selected group.</td></tr>`;
        recalculateBill();
        return;
      }

      activities.forEach((activity, index) => {
        const activityName = activity.activity || "";
        rowsBody.insertAdjacentHTML("beforeend", `
          <tr>
            <td>
              ${escapeHtml(activityName)}
              <input type="hidden" name="module_record[bill_items][${index}][activity]" value="${escapeHtml(activityName)}">
            </td>
            <td>
              <button type="button" class="tci-open-btn" data-open-tci-modal data-activity="${escapeHtml(activityName)}" data-row-index="${index}">TCI</button>
              <input type="hidden" name="module_record[bill_items][${index}][tci_details]" value="[]" data-tci-details-input>
            </td>
            <td><input type="number" min="0" step="1" name="module_record[bill_items][${index}][no_of_unit]" value="0" data-bill-units></td>
            <td><input type="number" min="0" step="0.01" name="module_record[bill_items][${index}][rate]" value="0" data-bill-rate></td>
            <td><input type="number" min="0" step="0.01" name="module_record[bill_items][${index}][total_amount]" value="0" data-bill-total readonly></td>
            <td><input type="text" name="module_record[bill_items][${index}][remarks]" value=""></td>
          </tr>
        `);
      });

      recalculateBill();
    };

    const addTciRow = (data = {}) => {
      if (!tciRows) return;

      const indicators = tciMap[activeTciActivity] || tciMap.__all || [];
      const selectedIndicator = data.indicator || indicators[0]?.indicator || "";
      const mandatory = data.mandatory || indicators.find((row) => row.indicator === selectedIndicator)?.mandatory || "No";

      tciRows.insertAdjacentHTML("beforeend", `
        <tr>
          <td>
            <select data-tci-indicator>
              ${optionHtml(indicators, selectedIndicator)}
            </select>
          </td>
          <td><input type="text" value="${escapeHtml(mandatory)}" data-tci-mandatory readonly></td>
          <td>
            <select data-tci-village>
              <option value="">Select</option>
              ${optionHtml(villageOptions, data.village || "")}
            </select>
          </td>
          <td><input type="date" value="${escapeHtml(data.working_date || "")}" data-tci-date></td>
          <td><input type="number" min="0" step="1" value="${escapeHtml(data.number || "")}" data-tci-number></td>
          <td><button type="button" class="table-action danger" data-remove-tci-row>Remove</button></td>
        </tr>
      `);
    };

    icsSelect?.addEventListener("change", syncActivityGroupState);
    groupSelect?.addEventListener("change", () => buildActivityRows(selectedGroups()));

    rowsBody?.addEventListener("input", (event) => {
      if (event.target.matches("[data-bill-units], [data-bill-rate]")) recalculateBill();
    });

    rowsBody?.addEventListener("click", (event) => {
      const button = event.target.closest("[data-open-tci-modal]");
      if (!button || !tciModal) return;

      activeTciActivity = button.dataset.activity || "";
      activeTciInput = button.closest("tr")?.querySelector("[data-tci-details-input]");
      tciRows.innerHTML = "";

      let savedRows = [];
      try {
        savedRows = JSON.parse(activeTciInput?.value || "[]");
      } catch (_error) {
        savedRows = [];
      }

      if (savedRows.length) {
        savedRows.forEach((row) => addTciRow(row));
      } else {
        (tciMap[activeTciActivity] || tciMap.__all || []).forEach((row) => addTciRow(row));
      }

      if (!tciRows.children.length) {
        tciRows.innerHTML = `<tr><td colspan="6">No TCI mapped for this activity.</td></tr>`;
      }

      if (typeof tciModal.showModal === "function") {
        tciModal.showModal();
      } else {
        tciModal.setAttribute("open", "open");
      }
    });

    tciRows?.addEventListener("change", (event) => {
      if (!event.target.matches("[data-tci-indicator]")) return;

      const selected = event.target.value;
      const mandatory = (tciMap[activeTciActivity] || tciMap.__all || []).find((row) => row.indicator === selected)?.mandatory || "No";
      const mandatoryInput = event.target.closest("tr")?.querySelector("[data-tci-mandatory]");
      if (mandatoryInput) mandatoryInput.value = mandatory;
    });

    tciRows?.addEventListener("click", (event) => {
      const button = event.target.closest("[data-remove-tci-row]");
      if (button) button.closest("tr")?.remove();
    });

    billForm.querySelector("[data-add-tci-row]")?.addEventListener("click", () => addTciRow());

    billForm.querySelector("[data-apply-tci-modal]")?.addEventListener("click", () => {
      const details = Array.from(tciRows?.querySelectorAll("tr") || []).map((row) => ({
        indicator: row.querySelector("[data-tci-indicator]")?.value || "",
        mandatory: row.querySelector("[data-tci-mandatory]")?.value || "",
        village: row.querySelector("[data-tci-village]")?.value || "",
        working_date: row.querySelector("[data-tci-date]")?.value || "",
        number: row.querySelector("[data-tci-number]")?.value || ""
      })).filter((row) => row.indicator);

      if (activeTciInput) activeTciInput.value = JSON.stringify(details);
      if (typeof tciModal?.close === "function") tciModal.close();
      else tciModal?.removeAttribute("open");
    });

    billForm.querySelectorAll("[data-close-tci-modal]").forEach((button) => {
      button.addEventListener("click", () => {
        if (typeof tciModal?.close === "function") tciModal.close();
        else tciModal?.removeAttribute("open");
      });
    });

    syncActivityGroupState();
    if (selectedGroups().length) buildActivityRows(selectedGroups());
    else recalculateBill();
  });

  document.querySelectorAll("[data-list-action='pending']").forEach((button) => {
    button.addEventListener("click", () => {
      window.alert("This action is not configured yet.");
    });
  });

  const initializeLanguageSwitcher = () => {
    const boundLanguageButtons = window.__vrpBoundLanguageButtons ||= new WeakSet();
    const unboundSignatureShell = document.querySelector(
      "[data-agreement-signature-shell]:not([data-agreement-signature-bound])"
    );
    const unboundLanguageButton = Array.from(document.querySelectorAll("[data-language-option]"))
      .find((button) => !boundLanguageButtons.has(button));

    if (window.__vrpLanguageSwitcherInitialized && !unboundSignatureShell && !unboundLanguageButton) {
      const language = localStorage.getItem("vrp_language") || "en";
      if (language !== "en" && typeof window.__vrpApplyLanguage === "function") {
        window.__vrpApplyLanguage(language, document.querySelector(".app-main") || document.body);
      }
      return;
    }
    window.__vrpLanguageSwitcherInitialized = true;

    const switcher = document.querySelector("[data-language-switcher]");
    const languageButtons = Array.from(document.querySelectorAll("[data-language-option]"));
    const originalText = window.__vrpOriginalText ||= new WeakMap();
    const attributeNames = ["placeholder", "title", "aria-label", "data-turbo-confirm"];
    const translations = {
      "Language": "भाषा",
      "Dashboard": "डैशबोर्ड",
      "No Activity Mapping": "कुल मेप नहीं किये गये किसान",
      "No Training Mapping": "कुल फार्मर ट्रेनिंग से मेप नहीं किये गये किसान",
      "Training Mapped But No Entry": "कुल फार्मर ट्रेनिंग में किसान की एंट्री नहीं हुई",
      "Sign Out": "साइन आउट",
      "Training": "प्रशिक्षण",
      "Farmer Training": "किसान प्रशिक्षण",
      "Training Form": "प्रशिक्षण फॉर्म",
      "Farmer Training Form": "किसान प्रशिक्षण फॉर्म",
      "Training List": "प्रशिक्षण सूची",
      "Farmer Training Form List": "किसान प्रशिक्षण फॉर्म सूची",
      "Training Topic Mapping": "प्रशिक्षण टॉपिक मैपिंग",
      "Farmer Training Topic Mapping": "किसान प्रशिक्षण टॉपिक मैपिंग",
      "ट्रेनिंग प्रपत्र": "प्रशिक्षण फॉर्म",
      "VRP Targets": "वीआरपी लक्ष्य",
      "Recent Target Mappings": "हाल की लक्ष्य मैपिंग",
      "Target Mapping Master": "लक्ष्य मैपिंग मास्टर",
      "Target Mapping": "लक्ष्य मैपिंग",
      "Target Mapping Upload": "लक्ष्य मैपिंग अपलोड",
      "Target Mapping Data Upload": "लक्ष्य मैपिंग डेटा अपलोड",
      "AFL Upload": "एएफएल अपलोड",
      "VRP ICS Mapping": "वीआरपी आईसीएस मैपिंग",
      "LG Directory": "एलजी डायरेक्टरी",
      "All List": "सभी सूची",
      "State Entry": "राज्य प्रविष्टि",
      "District Entry": "जिला प्रविष्टि",
      "Block Entry": "ब्लॉक प्रविष्टि",
      "GP Entry": "जीपी प्रविष्टि",
      "Village Entry": "गांव प्रविष्टि",
      "Month Entry": "माह प्रविष्टि",
      "Stakeholder": "स्टेकहोल्डर",
      "Office Setup": "ऑफिस सेटअप",
      "Parent Office Add": "पैरेंट ऑफिस जोड़ें",
      "Parent Office": "पैरेंट ऑफिस",
      "Parent Office Name": "पैरेंट ऑफिस नाम",
      "Parent Office Type": "पैरेंट ऑफिस प्रकार",
      "Sub Parent Office": "सब पैरेंट ऑफिस",
      "Parent Category": "पैरेंट श्रेणी",
      "Sub Office Add": "सब ऑफिस जोड़ें",
      "Sub Office Name": "सब ऑफिस नाम",
      "Select Parent Office": "पैरेंट ऑफिस चुनें",
      "Select Parent Office Type": "पैरेंट ऑफिस प्रकार चुनें",
      "Project Add": "प्रोजेक्ट जोड़ें",
      "Project Name": "प्रोजेक्ट नाम",
      "Stakeholder Name": "स्टेकहोल्डर नाम",
      "Stakeholder Category": "स्टेकहोल्डर श्रेणी",
      "Stakeholder Role": "स्टेकहोल्डर व्यक्ति प्रकार",
      "Stakeholder Person Type": "स्टेकहोल्डर व्यक्ति प्रकार",
      "Role": "भूमिका",
      "Role Name": "भूमिका नाम",
      "Activity Setup": "गतिविधि सेटअप",
      "Main Activity": "मुख्य गतिविधि",
      "Main Activity Name": "मुख्य गतिविधि नाम",
      "Main Activity List": "मुख्य गतिविधि सूची",
      "Total Mapped Main Activities": "कुल मैप की गई मुख्य गतिविधियाँ",
      "Sub Activity": "उप गतिविधि",
      "Sub Activity Name": "उप गतिविधि नाम",
      "Sub Activity List": "उप गतिविधि सूची",
      "Total Mapped Sub-Activities": "कुल मैप की गई उप-गतिविधियाँ",
      "Total Mapped Villages": "कुल मैप किए गए गाँव",
      "Targeted Farmers": "लक्षित किसानों की संख्या",
      "Farmer-wise Target Mapping": "किसान-वार लक्ष्य मैपिंग",
      "Farmer-wise Achievement": "किसान-वार उपलब्धि",
      "Farmer-wise Pending Achievement": "किसान-वार लंबित उपलब्धि",
      "Activity-wise Target Mapping": "गतिविधि-वार लक्ष्य मैपिंग",
      "Activity-wise Achievement": "गतिविधि-वार उपलब्धि",
      "Activity-wise Pending Achievement": "गतिविधि-वार लंबित उपलब्धि",
      "Mapped Villages": "मैप किए गए गाँव",
      "Mapped Farmer Distinct": "मैप किए गए विशिष्ट किसान",
      "Main Activities": "मुख्य गतिविधियाँ",
      "Sub Activities": "उप-गतिविधियाँ",
      "Assigned Target": "असाइन किया गया लक्ष्य",
      "Achieved Target": "प्राप्त लक्ष्य",
      "Pending Target": "लंबित लक्ष्य",
      "User Register": "यूज़र रजिस्टर",
      "All User": "सभी यूज़र",
      "Registration": "पंजीकरण",
      "User Mapping": "यूज़र मैपिंग",
      "User Hierarchy Mapping": "यूज़र हाइरार्की मैपिंग",
      "Resource Person Type": "रिसोर्स पर्सन प्रकार",
      "Access Control": "एक्सेस कंट्रोल",
      "Access Control List": "एक्सेस कंट्रोल सूची",
      "VRP Registration": "वीआरपी पंजीकरण",
      "VRP Type": "वीआरपी प्रकार",
      "VRP List": "वीआरपी सूची",
      "VRP Approval": "वीआरपी अनुमोदन",
      "VRP Approval Queue": "वीआरपी अनुमोदन क्यू",
      "VRP Approval Form": "वीआरपी अनुमोदन फॉर्म",
      "VRP Approval List": "वीआरपी अनुमोदन सूची",
      "Saved Records": "सेव रिकॉर्ड",
      "All Training Records": "सभी प्रशिक्षण रिकॉर्ड",
      "All Farmer Training Records": "सभी किसान प्रशिक्षण रिकॉर्ड",
      "All Main Activities": "सभी मुख्य गतिविधियां",
      "All Sub Activities": "सभी उप गतिविधियां",
      "All Task Completion Indicators": "सभी कार्य पूर्णता संकेतक",
      "All Approvals": "सभी अनुमोदन",
      "All Access Control": "सभी एक्सेस कंट्रोल",
      "All VRP Bills": "सभी वीआरपी बिल",
      "Fields": "फील्ड",
      "Edit Record": "रिकॉर्ड एडिट करें",
      "Features": "विशेषताएं",
      "Save": "सेव",
      "Update": "अपडेट",
      "Clear": "क्लियर",
      "Upload": "अपलोड",
      "Export": "एक्सपोर्ट",
      "Export Excel": "एक्सेल एक्सपोर्ट",
      "Choose Excel": "एक्सेल चुनें",
      "Edit": "एडिट",
      "Delete": "डिलीट",
      "Activate": "एक्टिव करें",
      "Deactivate": "डीएक्टिव करें",
      "Active": "एक्टिव",
      "Inactive": "इनएक्टिव",
      "Pending": "पेंडिंग",
      "Approved": "अनुमोदित",
      "Rejected": "अस्वीकृत",
      "Action": "कार्रवाई",
      "Actions": "कार्रवाई",
      "Status": "स्थिति",
      "Saved At": "सेव समय",
      "Updated": "अपडेट समय",
      "Search": "खोजें",
      "Search records": "रिकॉर्ड खोजें",
      "Search users": "यूज़र खोजें",
      "Search VRP": "वीआरपी खोजें",
      "Search Target Mapping": "लक्ष्य मैपिंग खोजें",
      "Search AFL": "एएफएल खोजें",
      "Search dashboard": "डैशबोर्ड खोजें",
      "FCO Name": "एफसीओ नाम",
      "Registered Farmers": "पंजीकृत किसान",
      "Farmer List": "किसान सूची",
      "Select FCO Name": "एफसीओ नाम चुनें",
      "Select all": "सभी चुनें",
      "Cancel": "रद्द करें",
      "Cancel Edit": "एडिट रद्द करें",
      "Add More": "और जोड़ें",
      "Add Subordinates": "अधीनस्थ जोड़ें",
      "Apply": "लागू करें",
	      "Remove": "हटाएं",
	      "Remove this VRP ICS mapping?": "यह वीआरपी आईसीएस मैपिंग हटाएं?",
	      "Remove this target mapping?": "यह लक्ष्य मैपिंग हटाएं?",
	      "Delete this VRP ICS mapping?": "यह वीआरपी आईसीएस मैपिंग डिलीट करें?",
	      "Delete this target mapping?": "यह लक्ष्य मैपिंग डिलीट करें?",
	      "Close": "बंद करें",
      "View": "देखें",
      "View Targets": "लक्ष्य देखें",
      "Send for Approval": "अनुमोदन के लिए भेजें",
      "Upload Date": "अपलोड तारीख",
      "Material Title": "सामग्री शीर्षक",
      "ICS / Block": "आईसीएस / ब्लॉक",
      "Gram Name": "ग्राम का नाम",
      "Gram Code": "ग्राम कोड",
      "GRAM NAME": "ग्राम का नाम",
      "GRAM CODE": "ग्राम कोड",
      "Trainee Department": "प्रशिक्षणार्थी विभाग",
      "Trainer Name": "प्रशिक्षक नाम",
      "Trainer Contact": "प्रशिक्षक संपर्क",
      "Training Date": "प्रशिक्षण तारीख",
      "Training Location": "प्रशिक्षण स्थान",
      "Department": "विभाग",
      "Training Topic": "प्रशिक्षण टॉपिक",
      "Training Subject": "प्रशिक्षण विषय",
      "Training Description": "प्रशिक्षण विवरण",
      "Training Method": "प्रशिक्षण विधि",
      "Farmer Count": "किसान संख्या",
      "Selected Farmers": "चुने गए किसान",
      "Male Count": "पुरुष संख्या",
      "Female Count": "महिला संख्या",
      "Next Farmer Training Date": "अगली किसान प्रशिक्षण तारीख",
      "Training Register Upload": "प्रशिक्षण रजिस्टर अपलोड",
      "Training Photo Upload with Geo Tag": "जियो टैग के साथ प्रशिक्षण फोटो अपलोड",
      "State": "राज्य",
      "State Name": "राज्य नाम",
      "State Code": "राज्य कोड",
      "District": "जिला",
      "District Name": "जिला नाम",
      "District Code": "जिला कोड",
      "Block": "ब्लॉक",
      "Block Name": "ब्लॉक नाम",
      "Block Code": "ब्लॉक कोड",
      "Gram Panchayat": "ग्राम पंचायत",
      "Gram Panchayat Name": "ग्राम पंचायत नाम",
      "GP Code": "जीपी कोड",
      "Village": "गांव",
      "Village Name": "गांव नाम",
      "Village Code": "गांव कोड",
      "VRP": "वीआरपी",
      "FCO": "एफसीओ",
      "ICS": "आईसीएस",
      "Farmers": "किसान",
      "Farmer": "किसान",
      "Mapped Farmers": "मैप किए किसान",
      "Target Farmers": "लक्षित किसान",
      "Select Village Name to load mapped farmers.": "मैप किए किसान लोड करने के लिए गांव नाम चुनें।",
      "Select Village Name to load target farmers.": "लक्षित किसान लोड करने के लिए गांव नाम चुनें।",
      "No mapped farmers found for selected village.": "चुने गए गांव के लिए कोई मैप किसान नहीं मिला।",
      "No target farmers found for selected village.": "चुने गए गांव के लिए कोई लक्षित किसान नहीं मिला।",
      "Mapped Villages": "मैप किए गांव",
      "Mapped Village Work Area": "मैप गांव कार्य क्षेत्र",
      "Assigned Target Progress": "दिए गए लक्ष्य की प्रगति",
      "Farmer Month Follow-up": "किसान मासिक फॉलो-अप",
      "Target": "लक्ष्य",
      "Targets": "लक्ष्य",
      "Target Quantity": "लक्ष्य मात्रा",
      "Completed": "पूर्ण",
      "Progress": "प्रगति",
      "Month": "माह",
      "Financial Year": "वित्तीय वर्ष",
      "Week": "सप्ताह",
      "Start Date": "प्रारंभ तारीख",
      "End Date": "समाप्ति तारीख",
      "Priority": "प्राथमिकता",
      "Remarks": "टिप्पणी",
      "Unit": "यूनिट",
      "Rate": "दर",
      "Total Amount": "कुल राशि",
      "Grand Total": "कुल योग",
      "Payment Status": "भुगतान स्थिति",
      "Completion Status": "पूर्णता स्थिति",
      "Task Completion Indicator": "कार्य पूर्णता संकेतक",
      "Task Completion Indicators": "कार्य पूर्णता संकेतक",
      "Indicator": "संकेतक",
      "Mandatory": "अनिवार्य",
      "Working Date": "कार्य तारीख",
      "Number": "संख्या",
      "User Type": "यूज़र प्रकार",
      "User Name": "यूज़र नाम",
      "Full Name": "पूरा नाम",
      "Name": "नाम",
      "Father Husband Name": "पिता / पति का नाम",
      "Gender": "लिंग",
      "Date of Birth": "जन्म तारीख",
      "Date of Joining": "जॉइनिंग तारीख",
      "Aadhar No": "आधार नंबर",
      "Account No": "खाता नंबर",
      "IFSC Code": "आईएफएससी कोड",
      "Bank Name": "बैंक नाम",
      "Address": "पता",
      "Mobile": "मोबाइल",
      "Mobile No": "मोबाइल नंबर",
      "Email": "ईमेल",
      "Registered By": "पंजीकरणकर्ता",
      "Enrollment Date": "नामांकन तारीख",
	      "Office Category Add": "ऑफिस श्रेणी जोड़ें",
	      "Office Category": "ऑफिस श्रेणी",
	      "Office Name": "ऑफिस नाम",
      "Sub Office Add": "सब ऑफिस जोड़ें",
      "Sub Office Name": "सब ऑफिस नाम",
      "Office Level": "ऑफिस लेवल",
      "Select Office Category": "ऑफिस श्रेणी चुनें",
      "Select Office Name": "ऑफिस नाम चुनें",
      "Office": "ऑफिस",
      "FCOC-C": "एफसीओसी-सी",
      "Select FCOC-C": "एफसीओसी-सी चुनें",
      "TO": "टीओ",
      "Select TO": "टीओ चुनें",
      "Cluster Incharge": "क्लस्टर इंचार्ज",
      "Select Cluster Incharge": "क्लस्टर इंचार्ज चुनें",
      "Menu": "मेनू",
      "Sub Menu": "सब मेनू",
      "Module Name": "मॉड्यूल नाम",
      "Sub Module Name": "सब मॉड्यूल नाम",
      "Can View": "देख सकते हैं",
      "Can Create": "बना सकते हैं",
      "Can Edit": "एडिट कर सकते हैं",
      "Can Delete": "डिलीट कर सकते हैं",
      "Yes": "हाँ",
      "No": "नहीं",
      "High": "उच्च",
      "Medium": "मध्यम",
      "Low": "निम्न",
      "Male": "पुरुष",
      "Female": "महिला",
      "Other": "अन्य",
      "No records saved yet.": "अभी कोई रिकॉर्ड सेव नहीं है।",
      "No target mapping saved yet.": "अभी कोई लक्ष्य मैपिंग सेव नहीं है।",
      "No users registered yet.": "अभी कोई यूज़र पंजीकृत नहीं है।",
      "No target mapping records uploaded yet.": "अभी कोई लक्ष्य मैपिंग रिकॉर्ड अपलोड नहीं है।",
      "Select VRP to load mapped villages.": "मैप किए गांव लोड करने के लिए वीआरपी चुनें।",
      "Select FCO, ICS and Village to load farmers.": "किसान लोड करने के लिए एफसीओ, आईसीएस और गांव चुनें।",
      "Select FCO Name, ICS and Village to load farmers.": "किसान लोड करने के लिए एफसीओ नाम, आईसीएस और गांव चुनें।",
      "No farmers found for selected village.": "चुने गए गांव के लिए कोई किसान नहीं मिला।",
      "Mapped FCO / ICS / Village List": "मैप एफसीओ / आईसीएस / गांव सूची",
      "0 mapping selected": "0 मैपिंग चुनी गई",
      "Dashboard Reports": "डैशबोर्ड रिपोर्ट",
      "Dashboard Module": "डैशबोर्ड मॉड्यूल",
      "VRP training details save karne ke liye.": "वीआरपी प्रशिक्षण विवरण सेव करने के लिए।",
      "Farmer training details save karne ke liye.": "किसान प्रशिक्षण विवरण सेव करने के लिए।",
      "Saved training records dekhne ke liye.": "सेव प्रशिक्षण रिकॉर्ड देखने के लिए।",
      "Saved farmer training records dekhne ke liye.": "सेव किसान प्रशिक्षण रिकॉर्ड देखने के लिए।",
      "Training documents/videos upload karna.": "प्रशिक्षण दस्तावेज / वीडियो अपलोड करने के लिए।",
      "Location hierarchy maintain karne ke liye.": "स्थान हाइरार्की बनाए रखने के लिए।",
      "State, District, Block, GP, Village ek sath maintain karne ke liye.": "राज्य, जिला, ब्लॉक, जीपी और गांव एक साथ बनाए रखने के लिए।",
      "Stakeholder name aur logo maintain karna.": "स्टेकहोल्डर नाम और लोगो बनाए रखने के लिए।",
      "Main activity add karne ke liye.": "मुख्य गतिविधि जोड़ने के लिए।",
      "Sub activity add karne ke liye.": "उप गतिविधि जोड़ने के लिए।",
      "Saved main activities dekhne ke liye.": "सेव मुख्य गतिविधियां देखने के लिए।",
      "Saved sub activities dekhne ke liye.": "सेव उप गतिविधियां देखने के लिए।",
      "VRP type add karne ke liye.": "वीआरपी प्रकार जोड़ने के लिए।",
      "Saved access control records dekhne ke liye.": "सेव एक्सेस कंट्रोल रिकॉर्ड देखने के लिए।",
      "Live VRP, bill, payment, target, activity, aur training summary.": "वीआरपी, बिल, भुगतान, लक्ष्य, गतिविधि और प्रशिक्षण का लाइव सारांश।",
      "Your mapped farmers, villages, assigned targets, and completed work summary.": "आपके मैप किसान, गांव, दिए गए लक्ष्य और पूर्ण कार्य का सारांश।"
    };
    const englishAliases = {
      "ट्रेनिंग प्रपत्र": "Training Form",
      "VRP training details save karne ke liye.": "Save VRP training details.",
      "Saved training records dekhne ke liye.": "View saved training records.",
      "Training documents/videos upload karna.": "Upload training documents/videos.",
      "Location hierarchy maintain karne ke liye.": "Maintain the location hierarchy.",
      "State, District, Block, GP, Village ek sath maintain karne ke liye.": "Maintain State, District, Block, GP, and Village together.",
      "Stakeholder name aur logo maintain karna.": "Maintain stakeholder name and logo.",
      "Main activity add karne ke liye.": "Add main activity.",
      "Sub activity add karne ke liye.": "Add sub activity.",
      "Saved main activities dekhne ke liye.": "View saved main activities.",
      "Saved sub activities dekhne ke liye.": "View saved sub activities.",
      "VRP type add karne ke liye.": "Add VRP type.",
      "Saved access control records dekhne ke liye.": "View saved access control records.",
      "कुल मेप नहीं किये गये किसान": "No Activity Mapping",
      "कुल फार्मर ट्रेनिंग से मेप नहीं किये गये किसान": "No Training Mapping",
      "कुल फार्मर ट्रेनिंग में किसान की एंट्री नहीं हुई": "Training Mapped But No Entry"
    };
	    const englishTranslations = {
	      ...Object.fromEntries(Object.entries(translations).map(([english, hindi]) => [hindi, english])),
	      ...englishAliases
	    };
	    const marathiTranslations = {
	      "Language": "भाषा",
	      "Dashboard": "डॅशबोर्ड",
	      "Sign Out": "साइन आउट",
	      "Target Mapping": "लक्ष्य मॅपिंग",
	      "Target Mapping Upload": "लक्ष्य मॅपिंग अपलोड",
	      "AFL Upload": "एएफएल अपलोड",
	      "Target Mapping Master": "लक्ष्य मॅपिंग मास्टर",
	      "VRP ICS Mapping": "व्हीआरपी आयसीएस मॅपिंग",
	      "Recent Target Mappings": "अलीकडील लक्ष्य मॅपिंग",
	      "Recent VRP ICS Mappings": "अलीकडील व्हीआरपी आयसीएस मॅपिंग",
	      "Office Setup": "ऑफिस सेटअप",
	      "Office Category": "ऑफिस श्रेणी",
	      "Office Name": "ऑफिस नाव",
      "Sub Office Add": "सब ऑफिस जोडा",
      "Sub Office Name": "सब ऑफिस नाव",
	      "Office Level": "ऑफिस लेवल",
	      "Select Office Category": "ऑफिस श्रेणी निवडा",
	      "Select Office Name": "ऑफिस नाव निवडा",
	      "FCOC-C": "एफसीओसी-सी",
	      "Select FCOC-C": "एफसीओसी-सी निवडा",
	      "TO": "टीओ",
	      "Select TO": "टीओ निवडा",
	      "Cluster Incharge": "क्लस्टर इंचार्ज",
	      "Select Cluster Incharge": "क्लस्टर इंचार्ज निवडा",
	      "VRP Registration": "व्हीआरपी नोंदणी",
	      "User Register": "यूज़र नोंदणी",
	      "Edit": "एडिट",
	      "Delete": "डिलीट",
	      "Remove": "काढा",
	      "Remove this VRP ICS mapping?": "हे व्हीआरपी आयसीएस मॅपिंग काढायचे?",
	      "Remove this target mapping?": "हे लक्ष्य मॅपिंग काढायचे?",
	      "Delete this VRP ICS mapping?": "हे व्हीआरपी आयसीएस मॅपिंग डिलीट करायचे?",
	      "Delete this target mapping?": "हे लक्ष्य मॅपिंग डिलीट करायचे?",
	      "Action": "कारवाई",
	      "Save Mapping": "मॅपिंग सेव करा",
	      "Update Mapping": "मॅपिंग अपडेट करा",
	      "Save Target": "लक्ष्य सेव करा",
	      "Update Target": "लक्ष्य अपडेट करा",
	      "Cancel Edit": "एडिट रद्द करा",
	      "Select VRP": "व्हीआरपी निवडा",
	      "Select FCO": "एफसीओ निवडा",
	      "Select FCO Name": "एफसीओ नाव निवडा",
	      "Select ICS": "आयसीएस निवडा",
	      "Select Village": "गाव निवडा",
	      "FCO Name": "एफसीओ नाव",
	      "Registered Farmers": "नोंदणीकृत किसान",
	      "Farmer List": "किसान सूची",
	      "Select FCO Name, ICS and Village to load farmers.": "किसान लोड करण्यासाठी एफसीओ नाव, आयसीएस आणि गाव निवडा.",
	      "No farmers found for selected village.": "निवडलेल्या गावासाठी कोणतेही किसान सापडले नाहीत.",
	      "Select all": "सर्व निवडा",
	      "No VRP ICS mapping saved yet.": "अजून कोणतेही व्हीआरपी आयसीएस मॅपिंग सेव नाही.",
	      "No target mapping saved yet.": "अजून कोणतेही लक्ष्य मॅपिंग सेव नाही."
      ,"Training Form": "प्रशिक्षण फॉर्म",
	      "Farmer Training": "किसान प्रशिक्षण",
	      "Farmer Training Form": "किसान प्रशिक्षण फॉर्म",
	      "Farmer Training Form List": "किसान प्रशिक्षण फॉर्म सूची",
      "Training Topic Mapping": "प्रशिक्षण टॉपिक मॅपिंग",
	      "Farmer Training Topic Mapping": "किसान प्रशिक्षण टॉपिक मॅपिंग",
	      "Trainer Name": "प्रशिक्षक नाव",
	      "Trainer Contact": "प्रशिक्षक संपर्क",
	      "Farmer Count": "किसान संख्या",
	      "Selected Farmers": "निवडलेले किसान",
	      "Training Photo Upload with Geo Tag": "जिओ टॅगसह प्रशिक्षण फोटो अपलोड",
	      "Mapped Farmers": "मॅप केलेले किसान",
	      "Target Farmers": "लक्षित किसान",
	      "Select Village Name to load mapped farmers.": "मॅप केलेले किसान लोड करण्यासाठी गाव नाव निवडा.",
	      "Select Village Name to load target farmers.": "लक्षित किसान लोड करण्यासाठी गाव नाव निवडा.",
	      "No mapped farmers found for selected village.": "निवडलेल्या गावासाठी कोणतेही मॅप किसान सापडले नाहीत.",
	      "No target farmers found for selected village.": "निवडलेल्या गावासाठी कोणतेही लक्षित किसान सापडले नाहीत."
	    };
	    const odiaTranslations = {
	      "Language": "ଭାଷା",
	      "Dashboard": "ଡ୍ୟାସବୋର୍ଡ",
	      "Sign Out": "ସାଇନ୍ ଆଉଟ୍",
	      "Target Mapping": "ଟାର୍ଗେଟ୍ ମ୍ୟାପିଂ",
	      "Target Mapping Upload": "ଟାର୍ଗେଟ୍ ମ୍ୟାପିଂ ଅପଲୋଡ୍",
	      "AFL Upload": "ଏଏଫଏଲ୍ ଅପଲୋଡ୍",
	      "Target Mapping Master": "ଟାର୍ଗେଟ୍ ମ୍ୟାପିଂ ମାଷ୍ଟର",
	      "VRP ICS Mapping": "ଭିଆରପି ଆଇସିଏସ୍ ମ୍ୟାପିଂ",
	      "Recent Target Mappings": "ସମ୍ପ୍ରତି ଟାର୍ଗେଟ୍ ମ୍ୟାପିଂ",
	      "Recent VRP ICS Mappings": "ସମ୍ପ୍ରତି ଭିଆରପି ଆଇସିଏସ୍ ମ୍ୟାପିଂ",
	      "Office Setup": "ଅଫିସ୍ ସେଟଅପ୍",
	      "Office Category": "ଅଫିସ୍ ବର୍ଗ",
	      "Office Name": "ଅଫିସ୍ ନାମ",
      "Sub Office Add": "ସବ୍ ଅଫିସ୍ ଯୋଡନ୍ତୁ",
      "Sub Office Name": "ସବ୍ ଅଫିସ୍ ନାମ",
	      "Office Level": "ଅଫିସ୍ ସ୍ତର",
	      "Select Office Category": "ଅଫିସ୍ ବର୍ଗ ବାଛନ୍ତୁ",
	      "Select Office Name": "ଅଫିସ୍ ନାମ ବାଛନ୍ତୁ",
	      "FCOC-C": "ଏଫସିଓସି-ସି",
	      "Select FCOC-C": "ଏଫସିଓସି-ସି ବାଛନ୍ତୁ",
	      "TO": "ଟିଓ",
	      "Select TO": "ଟିଓ ବାଛନ୍ତୁ",
	      "Cluster Incharge": "କ୍ଲଷ୍ଟର ଇନଚାର୍ଜ",
	      "Select Cluster Incharge": "କ୍ଲଷ୍ଟର ଇନଚାର୍ଜ ବାଛନ୍ତୁ",
	      "VRP Registration": "ଭିଆରପି ପଞ୍ଜୀକରଣ",
	      "User Register": "ୟୁଜର ପଞ୍ଜୀକରଣ",
	      "Edit": "ଏଡିଟ୍",
	      "Delete": "ଡିଲିଟ୍",
	      "Remove": "ହଟାନ୍ତୁ",
	      "Remove this VRP ICS mapping?": "ଏହି ଭିଆରପି ଆଇସିଏସ୍ ମ୍ୟାପିଂ ହଟାଇବେ?",
	      "Remove this target mapping?": "ଏହି ଟାର୍ଗେଟ୍ ମ୍ୟାପିଂ ହଟାଇବେ?",
	      "Delete this VRP ICS mapping?": "ଏହି ଭିଆରପି ଆଇସିଏସ୍ ମ୍ୟାପିଂ ଡିଲିଟ୍ କରିବେ?",
	      "Delete this target mapping?": "ଏହି ଟାର୍ଗେଟ୍ ମ୍ୟାପିଂ ଡିଲିଟ୍ କରିବେ?",
	      "Action": "କାର୍ଯ୍ୟ",
	      "Save Mapping": "ମ୍ୟାପିଂ ସେଭ୍ କରନ୍ତୁ",
	      "Update Mapping": "ମ୍ୟାପିଂ ଅପଡେଟ୍ କରନ୍ତୁ",
	      "Save Target": "ଟାର୍ଗେଟ୍ ସେଭ୍ କରନ୍ତୁ",
	      "Update Target": "ଟାର୍ଗେଟ୍ ଅପଡେଟ୍ କରନ୍ତୁ",
	      "Cancel Edit": "ଏଡିଟ୍ ବାତିଲ୍",
	      "Select VRP": "ଭିଆରପି ବାଛନ୍ତୁ",
	      "Select FCO": "ଏଫସିଓ ବାଛନ୍ତୁ",
	      "Select FCO Name": "ଏଫସିଓ ନାମ ବାଛନ୍ତୁ",
	      "Select ICS": "ଆଇସିଏସ୍ ବାଛନ୍ତୁ",
	      "Select Village": "ଗ୍ରାମ ବାଛନ୍ତୁ",
	      "FCO Name": "ଏଫସିଓ ନାମ",
	      "Registered Farmers": "ପଞ୍ଜୀକୃତ କୃଷକ",
	      "Farmer List": "କୃଷକ ତାଲିକା",
	      "Select FCO Name, ICS and Village to load farmers.": "କୃଷକ ଲୋଡ୍ କରିବାକୁ ଏଫସିଓ ନାମ, ଆଇସିଏସ୍ ଏବଂ ଗ୍ରାମ ବାଛନ୍ତୁ.",
	      "No farmers found for selected village.": "ବାଛିଥିବା ଗ୍ରାମ ପାଇଁ କୌଣସି କୃଷକ ମିଳିଲେ ନାହିଁ.",
	      "Select all": "ସବୁ ବାଛନ୍ତୁ",
	      "No VRP ICS mapping saved yet.": "ଏପର୍ଯ୍ୟନ୍ତ କୌଣସି ଭିଆରପି ଆଇସିଏସ୍ ମ୍ୟାପିଂ ସେଭ୍ ହୋଇନାହିଁ.",
	      "No target mapping saved yet.": "ଏପର୍ଯ୍ୟନ୍ତ କୌଣସି ଟାର୍ଗେଟ୍ ମ୍ୟାପିଂ ସେଭ୍ ହୋଇନାହିଁ."
      ,"Training Form": "ପ୍ରଶିକ୍ଷଣ ଫର୍ମ",
	      "Farmer Training": "କୃଷକ ପ୍ରଶିକ୍ଷଣ",
	      "Farmer Training Form": "କୃଷକ ପ୍ରଶିକ୍ଷଣ ଫର୍ମ",
	      "Farmer Training Form List": "କୃଷକ ପ୍ରଶିକ୍ଷଣ ଫର୍ମ ତାଲିକା",
      "Training Topic Mapping": "ପ୍ରଶିକ୍ଷଣ ଟପିକ୍ ମ୍ୟାପିଂ",
	      "Farmer Training Topic Mapping": "କୃଷକ ପ୍ରଶିକ୍ଷଣ ଟପିକ୍ ମ୍ୟାପିଂ",
	      "Trainer Name": "ପ୍ରଶିକ୍ଷକ ନାମ",
	      "Trainer Contact": "ପ୍ରଶିକ୍ଷକ ଯୋଗାଯୋଗ",
	      "Farmer Count": "କୃଷକ ସଂଖ୍ୟା",
	      "Selected Farmers": "ବାଛିଥିବା କୃଷକ",
	      "Training Photo Upload with Geo Tag": "ଜିଓ ଟ୍ୟାଗ୍ ସହିତ ପ୍ରଶିକ୍ଷଣ ଫଟୋ ଅପଲୋଡ୍",
	      "Mapped Farmers": "ମ୍ୟାପ୍ ହୋଇଥିବା କୃଷକ",
	      "Target Farmers": "ଲକ୍ଷ୍ୟ କୃଷକ",
	      "Select Village Name to load mapped farmers.": "ମ୍ୟାପ୍ ହୋଇଥିବା କୃଷକ ଲୋଡ୍ କରିବାକୁ ଗ୍ରାମ ନାମ ବାଛନ୍ତୁ.",
	      "Select Village Name to load target farmers.": "ଲକ୍ଷ୍ୟ କୃଷକ ଲୋଡ୍ କରିବାକୁ ଗ୍ରାମ ନାମ ବାଛନ୍ତୁ.",
	      "No mapped farmers found for selected village.": "ବାଛିଥିବା ଗ୍ରାମ ପାଇଁ କୌଣସି ମ୍ୟାପ୍ କୃଷକ ମିଳିଲେ ନାହିଁ.",
	      "No target farmers found for selected village.": "ବାଛିଥିବା ଗ୍ରାମ ପାଇଁ କୌଣସି ଲକ୍ଷ୍ୟ କୃଷକ ମିଳିଲେ ନାହିଁ."
	    };
	    const languageTranslations = {
	      hi: translations,
	      mr: marathiTranslations,
	      or: odiaTranslations
	    };

    const googleLanguageCodes = { en: "en", hi: "hi", mr: "mr", or: "or", gu: "gu" };
    const setGoogleTranslateCookie = (language) => {
      const value = `/en/${googleLanguageCodes[language] || "en"}`;
      document.cookie = `googtrans=${value};path=/`;
      document.cookie = `googtrans=${value};path=/;domain=${window.location.hostname}`;
    };
    const initializeGoogleTranslate = () => {
      const holder = document.getElementById("google_translate_element");
      if (!holder || holder.dataset.googleInitialized === "true") return;
      if (!window.google?.translate?.TranslateElement) return;
      holder.dataset.googleInitialized = "true";
      new window.google.translate.TranslateElement({
        pageLanguage: "en", includedLanguages: "en,hi,mr,or,gu", autoDisplay: false
      }, "google_translate_element");
    };
    const loadGoogleTranslate = () => {
      if (window.google?.translate?.TranslateElement) {
        initializeGoogleTranslate();
        return Promise.resolve();
      }
      if (window.__vrpGoogleTranslateLoading) return window.__vrpGoogleTranslateLoading;

      window.__vrpGoogleTranslateLoading = new Promise((resolve) => {
        window.googleTranslateElementInit = () => {
          initializeGoogleTranslate();
          resolve();
        };

        const script = document.createElement("script");
        script.src = "https://translate.google.com/translate_a/element.js?cb=googleTranslateElementInit";
        script.async = true;
        script.onerror = () => {
          window.__vrpGoogleTranslateLoading = null;
          script.remove();
          resolve();
        };
        document.head.appendChild(script);
      });

      return window.__vrpGoogleTranslateLoading;
    };
    const applyGoogleLanguage = (language) => {
      const requestId = window.__vrpGoogleLanguageRequest = (window.__vrpGoogleLanguageRequest || 0) + 1;
      setGoogleTranslateCookie(language);
      if (language === "en" && !window.google?.translate?.TranslateElement && !window.__vrpGoogleTranslateLoading) return;

      loadGoogleTranslate().then(() => {
        // The script callback can run before Google has populated its select.
        const applyWhenReady = (attempt = 0) => {
          if (requestId !== window.__vrpGoogleLanguageRequest) return;
          const combo = document.querySelector(".goog-te-combo");
          const code = googleLanguageCodes[language] || "en";
          if (combo && Array.from(combo.options).some((option) => option.value === code)) {
            combo.value = code;
            combo.dispatchEvent(new Event("change", { bubbles: true }));
          } else if (attempt < 100) {
            setTimeout(() => applyWhenReady(attempt + 1), 100);
          }
        };
        applyWhenReady();
      });
    };

    const preserveSpacing = (original, replacement) => {
      const leading = original.match(/^\s*/)?.[0] || "";
      const trailing = original.match(/\s*$/)?.[0] || "";
      return `${leading}${replacement}${trailing}`;
    };

    const translatePhrase = (text, language) => {
      const trimmed = text.trim();
      if (!trimmed) return text;
      if (/^[\s\d.,:;/%#()\-–—|]+$/.test(trimmed)) return text;

	      const selectedTranslations = languageTranslations[language] || {};
	      const exact = language === "en" ? englishTranslations[trimmed] : selectedTranslations[trimmed];
	      if (exact) return preserveSpacing(text, exact);

      const labelNumberMatch = trimmed.match(/^(.+?):\s*(\d+)$/);
      if (labelNumberMatch) {
        const translatedLabel = translatePhrase(labelNumberMatch[1], language).trim();
        if (translatedLabel && translatedLabel !== labelNumberMatch[1]) {
          return preserveSpacing(text, `${translatedLabel}: ${labelNumberMatch[2]}`);
        }
      }

	      if (language === "en") return text;
	      if (language !== "hi") return text;

      let match = trimmed.match(/^Select (.+)$/);
      if (match) return preserveSpacing(text, `${translatePhrase(match[1], "hi").trim()} चुनें`);

      match = trimmed.match(/^Enter (.+)$/);
      if (match) return preserveSpacing(text, `${translatePhrase(match[1], "hi").trim()} दर्ज करें`);

      match = trimmed.match(/^Search (.+)$/);
      if (match) return preserveSpacing(text, `${translatePhrase(match[1], "hi").trim()} खोजें`);

      match = trimmed.match(/^No (.+) saved yet\.$/);
      if (match) return preserveSpacing(text, `अभी कोई ${translatePhrase(match[1], "hi").trim()} सेव नहीं है।`);

      match = trimmed.match(/^(\d+) records$/);
      if (match) return preserveSpacing(text, `${match[1]} रिकॉर्ड`);

      match = trimmed.match(/^Page (\d+) of (\d+)$/);
      if (match) return preserveSpacing(text, `पेज ${match[1]} / ${match[2]}`);

      match = trimmed.match(/^(\d+) to (\d+) of (\d+)$/);
      if (match) return preserveSpacing(text, `${match[1]} से ${match[2]} कुल ${match[3]}`);

      return text;
    };

    const translateTextNode = (node, language) => {
      if (!node.nodeValue.trim()) return;
      const parent = node.parentElement;
      if (!parent || parent.closest("script, style, textarea, code, pre, .skiptranslate, #google_translate_element, font[style]")) return;

      const original = originalText.get(node) || node.nodeValue;
      originalText.set(node, original);
      // An option without an explicit value derives its submitted value from its text.
      if (parent.tagName === "OPTION" && !parent.hasAttribute("value")) parent.setAttribute("value", parent.textContent);
      const translated = replaceVrpUiText(translatePhrase(original, language));
      if (node.nodeValue !== translated) node.nodeValue = translated;
    };

    const translateAttributes = (element, language) => {
      attributeNames.forEach((attribute) => {
        const value = element.getAttribute(attribute);
        if (!value) return;

        const dataKey = `i18nOriginal${attribute.replace(/(^|-)([a-z])/g, (_match, _dash, letter) => letter.toUpperCase())}`;
        const original = element.dataset[dataKey] || value;
        element.dataset[dataKey] = original;
        const translated = replaceVrpUiText(translatePhrase(original, language));
        if (element.getAttribute(attribute) !== translated) element.setAttribute(attribute, translated);
      });

      if ((element.matches("input[type='submit'], input[type='button']")) && element.value) {
        element.dataset.i18nOriginalValue ||= element.value;
        element.value = replaceVrpUiText(translatePhrase(element.dataset.i18nOriginalValue, language)).trim();
      }
    };

    let languageApplying = false;
	    const applyLanguage = (language, root = document.body) => {
      languageApplying = true;
	      document.documentElement.lang = language;
      document.title = replaceVrpUiText(document.title);
      languageButtons.forEach((button) => {
        button.classList.toggle("active", button.dataset.languageOption === language);
      });

      if (language === "en" && !window.__vrpHadNonEnglishLanguage) {
        root.querySelectorAll("*").forEach((element) => {
          translateAttributes(element, language);
          element.childNodes.forEach((node) => {
            if (node.nodeType === Node.TEXT_NODE) translateTextNode(node, language);
          });
        });
        languageApplying = false;
        return;
      }
      if (language !== "en") window.__vrpHadNonEnglishLanguage = true;

      root.querySelectorAll("*").forEach((element) => {
        translateAttributes(element, language);
        element.childNodes.forEach((node) => {
          if (node.nodeType === Node.TEXT_NODE) translateTextNode(node, language);
        });
      });
      languageApplying = false;
	    };

      window.__vrpApplyLanguage = applyLanguage;

	    const setLanguage = (language) => {
      const nextLanguage = ["en", "hi", "mr", "or", "gu"].includes(language) ? language : "en";
      localStorage.setItem("vrp_language", nextLanguage);
      applyGoogleLanguage(nextLanguage);
      applyLanguage(nextLanguage);
    };

    if (switcher) {
      languageButtons.forEach((button) => {
        if (boundLanguageButtons.has(button)) return;

        boundLanguageButtons.add(button);
        button.dataset.languageBound = "true";
        button.addEventListener("click", () => setLanguage(button.dataset.languageOption));
      });
    }

    document.querySelectorAll("[data-agreement-signature-shell]").forEach((shell) => {
      if (shell.dataset.agreementSignatureBound === "true") return;

      const canvas = shell.querySelector("[data-agreement-signature-pad]");
      const input = document.querySelector("[data-agreement-signature-input]");
      const clearButton = shell.querySelector("[data-agreement-signature-clear]");
      const form = document.querySelector("[data-agreement-form]");
      const acceptButton = document.querySelector("[data-agreement-accept]");
      if (!canvas || !input || !form) return;

      const context = canvas.getContext("2d");
      if (!context) return;

      shell.dataset.agreementSignatureBound = "true";
      canvas.style.touchAction = "none";

      let drawing = false;
      let lastPoint = null;
      let signatureDrawn = false;

      const applyPenStyle = () => {
        context.lineWidth = 2.4;
        context.lineCap = "round";
        context.lineJoin = "round";
        context.strokeStyle = "#1f4d3a";
      };

      const resizeCanvas = () => {
        const { width, height } = canvas.getBoundingClientRect();
        if (!width || !height) return;

        canvas.width = Math.floor(width);
        canvas.height = Math.floor(height);
        context.clearRect(0, 0, canvas.width, canvas.height);
        input.value = "";
        signatureDrawn = false;
        if (acceptButton) acceptButton.disabled = true;
        applyPenStyle();
      };

      const pointerPoint = (event) => {
        const rect = canvas.getBoundingClientRect();
        return {
          x: event.clientX - rect.left,
          y: event.clientY - rect.top
        };
      };

      const syncSignature = () => {
        if (!signatureDrawn) {
          input.value = "";
          if (acceptButton) acceptButton.disabled = true;
          return;
        }

        input.value = canvas.toDataURL("image/png");
        if (acceptButton) acceptButton.disabled = !input.value;
      };

      const stopDrawing = () => {
        if (!drawing) return;
        drawing = false;
        lastPoint = null;
        syncSignature();
      };

      resizeCanvas();
      window.addEventListener("resize", resizeCanvas);

      canvas.addEventListener("pointerdown", (event) => {
        event.preventDefault();
        drawing = true;
        canvas.setPointerCapture(event.pointerId);
        lastPoint = pointerPoint(event);
        context.beginPath();
        context.moveTo(lastPoint.x, lastPoint.y);
      });

      canvas.addEventListener("pointermove", (event) => {
        if (!drawing || !lastPoint) return;
        event.preventDefault();
        const point = pointerPoint(event);
        context.lineTo(point.x, point.y);
        context.stroke();
        lastPoint = point;
        signatureDrawn = true;
      });

      canvas.addEventListener("pointerup", stopDrawing);
      canvas.addEventListener("pointercancel", stopDrawing);
      canvas.addEventListener("pointerleave", stopDrawing);

      clearButton?.addEventListener("click", () => {
        context.clearRect(0, 0, canvas.width, canvas.height);
        input.value = "";
        signatureDrawn = false;
        if (acceptButton) acceptButton.disabled = true;
      });

      form.addEventListener("submit", (event) => {
        const decision = event.submitter?.value || "";
        if (decision === "agree" && !input.value) {
          event.preventDefault();
          window.alert("Please sign before accepting the declaration.");
        }
      });
    });

    setLanguage(localStorage.getItem("vrp_language") || "en");

    window.__vrpLanguageObserver?.disconnect();
    window.__vrpLanguageObserver = new MutationObserver((mutations) => {
      if (languageApplying) return;
      const language = localStorage.getItem("vrp_language") || "en";
      // Translate inserted UI only; rescanning the page would overwrite Google's
      // translated text and repeatedly walk large, paginated tables.
      mutations.forEach((mutation) => mutation.addedNodes.forEach((node) => {
        if (node.nodeType === Node.TEXT_NODE) {
          if (!originalText.has(node)) translateTextNode(node, language);
        } else if (node.nodeType === Node.ELEMENT_NODE) {
          if (node.closest(".skiptranslate, #google_translate_element, font[style]")) return;
          translateAttributes(node, language);
          const walker = document.createTreeWalker(node, NodeFilter.SHOW_TEXT);
          while (walker.nextNode()) {
            if (!originalText.has(walker.currentNode)) translateTextNode(walker.currentNode, language);
          }
          node.querySelectorAll("[placeholder], [title], [aria-label], [data-turbo-confirm]").forEach((element) => translateAttributes(element, language));
        }
      }));
    });
    window.__vrpLanguageObserver.observe(document.body, { childList: true, subtree: true });
  };

  initializeLanguageSwitcher();
}

const bootLayoutPage = () => {
  if (document.querySelector(".login-page")) {
    initPasswordToggles();
    return;
  }

  initFastNavigation();
  initAflFarmerMapping();
  scheduleDeferredLayoutInit();
};

const queueBootLayoutPage = () => {
  if (window.__vrpBootQueued) return;

  window.__vrpBootQueued = true;
  window.requestAnimationFrame(() => {
    window.__vrpBootQueued = false;
    bootLayoutPage();
  });
};

document.addEventListener("turbo:load", queueBootLayoutPage);
document.addEventListener("DOMContentLoaded", queueBootLayoutPage);

if (document.readyState !== "loading") {
  queueBootLayoutPage();
}
