{- Shell Equivalents
Copyright (C) 2004-2007 John Goerzen <jgoerzen@complete.org>
Please see the COPYRIGHT file
-}

{- |
   Module     : HSH.ShellEquivs
   Copyright  : Copyright (C) 2007 John Goerzen
   License    : GNU LGPL, version 2.1 or above

   Maintainer : John Goerzen <jgoerzen@complete.org> 
   Stability  : provisional
   Portability: portable

Copyright (c) 2006-2007 John Goerzen, jgoerzen\@complete.org

This module provides shell-like commands.  Most, but not all, are designed
to be used directly as part of a HSH pipeline.  All may be used outside
HSH entirely as well.

-}

module HSH.ShellEquivs(
                       abspath,
                       basename,
                       dirname,
                       catFrom,
                       catFromS,
                       catTo,
                       cd,
                       exit,
                       grep,
                       grepV,
                       egrep,
                       egrepV,
                       pwd,
                       readlink,
                       readlinkabs,
                       tee,
                       wcL,
                      ) where

import HSH.Command
import Data.List
import Text.Regex
import Control.Monad
import Control.Exception(evaluate)
import System.Directory
import System.Posix.Files
import System.Path
import System.Exit

{- | Load the specified files and display them, one at a time. 

The special file @-@ means to display the input.

If it is not given, no input is read.

Unlike the shell cat, @-@ may be given twice.  However, if it is, you
will be forcing Haskell to buffer the input. 

Note: buffering behavior here is untested. 
-}
catFrom :: [FilePath] -> String -> IO String
catFrom fplist inp =
    do r <- foldM foldfunc "" fplist
       return r
    where foldfunc accum fp =
                  case fp of
                    "-" -> return (accum ++ inp)
                    fn -> do c <- readFile fn
                             return (accum ++ c)

{- | Takes input, writes it to the specified file, and does not pass it on. 
     See also 'tee'. -}
catTo :: FilePath -> String -> IO String
catTo fp inp =
    do writeFile fp inp
       return ""

{- | Takes a string and sends it on as standard output.

The input to this function is never read. -}
catFromS :: String -> String -> String
catFromS inp _ = inp

{- | Takes input, writes it to all the specified files, and passes it on.

This function buffers the input. 

See also 'catFrom'. -}
tee :: [FilePath] -> String -> IO String
tee [] inp = return inp
tee (x:xs) inp = do writeFile x inp
                    tee xs inp

{- | Search for the string in the lines.  Return those that match. -}
grep :: String -> [String] -> [String]
grep needle = filter (isInfixOf needle)

{- | Search for the string in the lines.  Return those that do NOT match. -}
grepV :: String -> [String] -> [String]
grepV needle = filter (not . isInfixOf needle)

{- | Search for the regexp in the lines.  Return those that match. -}
egrep :: String -> [String] -> [String]
egrep pat = filter (ismatch regex)
    where regex = mkRegex pat
          ismatch r inp = case matchRegex r inp of
                            Nothing -> False
                            Just _ -> True

{- | Search for the regexp in the lines.  Return those that do NOT match. -}
egrepV :: String -> [String] -> [String]
egrepV pat = filter (not . ismatch regex)
    where regex = mkRegex pat
          ismatch r inp = case matchRegex r inp of
                            Nothing -> False
                            Just _ -> True

{- | Count number of lines.  wc -l -}
wcL :: [String] -> [String]
wcL inp = [show $ genericLength inp]

{- | An alias for System.Directory.getCurrentDirectory -}
pwd :: IO FilePath
pwd = getCurrentDirectory

{- | An alias for System.Directory.setCurrentDirectory -}
cd :: FilePath -> IO ()
cd = setCurrentDirectory

{- | Return the absolute path of the arg.  Raises an error if the
computation is impossible. -}
abspath :: FilePath -> IO FilePath
abspath inp =
    do p <- pwd
       case absNormPath p inp of
         Nothing -> fail $ "Cannot make " ++ show inp ++ " absolute within " ++
                    show p
         Just x -> return x

{- | Return the destination that the given symlink points to.
An alias for System.Posix.Files.readSymbolicLink -}
readlink :: FilePath -> IO FilePath
readlink fp = 
    do issym <- (getFileStatus fp >>= return . isSymbolicLink)
       if issym
           then readSymbolicLink fp
           else return fp

{- | As 'readlink', but turns the result into an absolute path. -}
readlinkabs :: FilePath -> IO FilePath
readlinkabs inp = 
    do do issym <- (getFileStatus inp >>= return . isSymbolicLink)
          if issym 
             then do rl <- readlink inp
                     case absNormPath (dirname inp) rl of
                       Nothing -> fail $ "Cannot make " ++ show rl ++ " absolute within " ++
                                  show (dirname inp)
                       Just x -> return x
             else abspath inp

splitpath "" = (".", ".")
splitpath "/" = ("/", "/")
splitpath p 
    | last p == '/' = splitpath (init p)
    | not ('/' `elem` p) = (".", p)
    | head p == '/' && length (filter (== '/') p) == 1 = ("/", tail p)
    | otherwise = (\(base, dir) -> (reverse (tail dir), reverse base))
        (break (== '/') (reverse p))

{- | The filename part of a path -}
basename :: FilePath -> FilePath
basename = snd . splitpath

{- | The directory part of a path -}
dirname :: FilePath -> FilePath
dirname = fst . splitpath

{- | Exits with the specified error code. 0 indicates no error. -}
exit :: Int -> IO a
exit code 
    | code == 0 = exitWith ExitSuccess
    | otherwise = exitWith (ExitFailure code)
