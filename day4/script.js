// Select the HTML elements
const noteText = document.querySelector("#note-text");
const charCount = document.querySelector("#char-count");
const wordCount = document.querySelector("#word-count");
const clearBtn = document.querySelector("#clear-btn");
const themeToggle = document.querySelector("#theme-toggle");

// Keys used to save information in the browser
const DRAFT_KEY = "notes-toolkit-draft";
const THEME_KEY = "notes-toolkit-theme";

// Update the character and word counters
function updateCounts() {
  const text = noteText.value;
  const characters = text.length;
  const trimmedText = text.trim();

  let words = 0;

  if (trimmedText !== "") {
    words = trimmedText.split(/\s+/).length;
  }

  charCount.textContent = characters + " / 200 characters";
  wordCount.textContent = words + " words";

  charCount.classList.remove("warning", "over");

  if (characters > 200) {
    charCount.classList.add("over");
  } else if (characters > 180) {
    charCount.classList.add("warning");
  }
}

// Save the note in the browser
function saveDraft() {
  localStorage.setItem(DRAFT_KEY, noteText.value);
}

// Load the saved note
function loadDraft() {
  const savedDraft = localStorage.getItem(DRAFT_KEY);

  if (savedDraft !== null) {
    noteText.value = savedDraft;
  }
}

// Apply the selected theme
function applyTheme(theme) {
  if (theme === "dark") {
    document.body.classList.add("dark");
    themeToggle.textContent = "Light mode";
  } else {
    document.body.classList.remove("dark");
    themeToggle.textContent = "Dark mode";
  }
}

// Load the saved theme
function loadTheme() {
  const savedTheme = localStorage.getItem(THEME_KEY);

  if (savedTheme === "dark") {
    applyTheme("dark");
  } else {
    applyTheme("light");
  }
}

// Update counters and save whenever the user types
noteText.addEventListener("input", function () {
  updateCounts();
  saveDraft();
});

// Clear the note
function clearNote() {
  noteText.value = "";
  localStorage.removeItem(DRAFT_KEY);

  updateCounts();
  noteText.focus();
}

// Respond to the Clear button
clearBtn.addEventListener("click", function () {
  clearNote();
});

// Clear the note when Escape is pressed
noteText.addEventListener("keydown", function (event) {
  if (event.key === "Escape") {
    clearNote();
  }
});

// Switch between light and dark themes
themeToggle.addEventListener("click", function () {
  const isDark = document.body.classList.contains("dark");
  let newTheme = "dark";

  if (isDark) {
    newTheme = "light";
  }

  applyTheme(newTheme);
  localStorage.setItem(THEME_KEY, newTheme);
});

// Restore saved information when the page opens
loadDraft();
loadTheme();
updateCounts();