CREATE TABLE `Course` (
  `Id` VARCHAR(191) NOT NULL,
  `Name` VARCHAR(191) NOT NULL,
  `Semester` VARCHAR(191) NOT NULL,
  `Year` INTEGER NOT NULL,
  `CreatedAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`Id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `Student` (
  `Id` VARCHAR(191) NOT NULL,
  `CourseId` VARCHAR(191) NOT NULL,
  `StudentNumber` VARCHAR(191) NOT NULL,
  `Name` VARCHAR(191) NOT NULL,
  `Email` VARCHAR(191) NOT NULL,
  `GithubUsername` VARCHAR(191) NOT NULL,
  `CreatedAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE INDEX `Student_CourseId_StudentNumber_key`(`CourseId`, `StudentNumber`),
  INDEX `Student_CourseId_Name_idx`(`CourseId`, `Name`),
  PRIMARY KEY (`Id`),
  CONSTRAINT `Student_CourseId_fkey` FOREIGN KEY (`CourseId`) REFERENCES `Course`(`Id`) ON DELETE CASCADE ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `Repository` (
  `Id` VARCHAR(191) NOT NULL,
  `StudentId` VARCHAR(191) NOT NULL,
  `Name` VARCHAR(191) NOT NULL,
  `RepositoryUrl` VARCHAR(2048) NOT NULL,
  `Owner` VARCHAR(191) NOT NULL,
  `RepositoryName` VARCHAR(191) NOT NULL,
  `IsActive` BOOLEAN NOT NULL DEFAULT true,
  `LastSyncedAt` DATETIME(3) NULL,
  `CreatedAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  INDEX `Repository_StudentId_IsActive_idx`(`StudentId`, `IsActive`),
  PRIMARY KEY (`Id`),
  CONSTRAINT `Repository_StudentId_fkey` FOREIGN KEY (`StudentId`) REFERENCES `Student`(`Id`) ON DELETE CASCADE ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `Commit` (
  `Id` VARCHAR(191) NOT NULL,
  `RepositoryId` VARCHAR(191) NOT NULL,
  `Sha` VARCHAR(64) NOT NULL,
  `Message` TEXT NOT NULL,
  `AuthorName` VARCHAR(191) NOT NULL,
  `AuthorEmail` VARCHAR(191) NOT NULL,
  `CommittedAt` DATETIME(3) NOT NULL,
  `CommitUrl` VARCHAR(2048) NOT NULL,
  `CreatedAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE INDEX `Commit_RepositoryId_Sha_key`(`RepositoryId`, `Sha`),
  INDEX `Commit_RepositoryId_CommittedAt_idx`(`RepositoryId`, `CommittedAt`),
  PRIMARY KEY (`Id`),
  CONSTRAINT `Commit_RepositoryId_fkey` FOREIGN KEY (`RepositoryId`) REFERENCES `Repository`(`Id`) ON DELETE CASCADE ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;